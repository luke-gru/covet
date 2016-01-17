require 'optparse'
require 'json'
require 'set'
require_relative 'log_file'
require_relative 'collection_filter'
require_relative 'run_list_printer'
require_relative 'version'
require_relative 'vcs'
require_relative 'utils'

module Covet
  class CLI
    class << self
      attr_accessor :options
    end

    def initialize(argv)
      @argv = argv
    end

    # TODO: process cmdline options for
    #   - specify VCS [ ]
    #   - specify test seed (ordering)
    #   - stats (show filtered files, files to run vs files to ignore, etc.)
    def run
      options = nil
      begin
        options = Options.parse!(@argv)
        self.class.options = options
      rescue OptionParser::InvalidArgument, OptionParser::InvalidOption => e
        Kernel.abort "Error: #{e.message}"
      end

      # Run coverage collection
      if options[:collect_cmdline] && !options[:collect_cmdline].empty?
        cmd = options[:collect_cmdline]
        env_options = { 'COVET_COLLECT' => '1' }
        if options[:collect_gem_whitelist].any?
          env_options['COVET_GEM_WHITELIST'] = %Q("#{options[:collect_gem_whitelist].join(',')}")
        end
        if options[:test_runner] != Options::DEFAULTS[:test_runner]
          env_options['COVET_TEST_RUNNER'] = %Q("#{options[:test_runner]}")
        end
        env_list_str = env_options.to_a.map { |ary| ary[0] + '=' + ary[1] }.join(' ')
        cmd = %Q(#{env_list_str} #{cmd})
        puts cmd
        puts "Collecting coverage information for each test method..."
        Kernel.exec cmd
      end

      # Gather run list for printing or execution by finding changed files and
      # lines using version control system, and compare those changed files
      # and lines with the coverage information that was gathered during
      # coverage collection for each test method.
      revision = options[:revision]
      line_changes = nil # establish scope
      begin
        line_changes = VCS.changes_since(revision)
      rescue Rugged::RepositoryError
        Kernel.abort "Error: #{Dir.pwd} is not a git repository. " \
          "Make sure you're in the project root."
      rescue Rugged::Error, Rugged::InvalidError, TypeError
        Kernel.abort "Error: #{options[:revision]} is not a valid revision reference in #{options[:VCS]}"
      end
      if line_changes.empty?
        if revision.to_s == 'last_commit'
          revision = "last commit" # prettier output below
        end
        if options[:print_run_list] && options[:print_run_list_format] == :json
          puts JSON.dump({'test_files' => [], 'meta' => { 'no_file_changes' => true}})
        else
          puts "# No changes since #{revision}. You can specify the #{options[:VCS]} revision using the --revision option."
        end
        Kernel.exit
      end

      cov_map = Hash.new { |h, file| h[file] = Hash.new { |i, line| i[line] = [] } }
      logfile = LogFile.new(:mode => 'r')

      unless logfile.file_exists?
        Kernel.abort "Error: The coverage log file doesn't exist.\n" \
          "You need to collect info first with 'covet -c $TEST_CMD'\n" \
          "Ex: covet -c \"rake test\""
      end

      all_test_files = Set.new
      run_stats = {}
      # Read in the coverage info
      logfile.load_each_buf! do |buf|
        buf.each do |args|
          if args[0] == 'base' # first value logged
            run_options = args.last
            if run_options['version'] != Covet::VERSION
              warn "Warning - the run log was created with another version of covet " \
              "(#{run_options['version']}), which is not guaranteed to be compatible " \
              "with this version of covet (#{Covet::VERSION}). Please run 'covet -c' again."
            end
          end

          if args[0] == 'stats' # last value logged
            run_stats.update(args.last)
            next
          end

          desc = args[0] # @var String, test file, with possible method name
          delta = args[1] # @var Hash|nil, hash of application code filenames to changed lines in those files
          next if delta.nil? # no coverage difference
          #stats = args[2]

          delta.each_pair do |fname, lines_hash|
            next if options[:ignore_changed_files].include?(fname)
            all_test_files << fname
            file_map = cov_map[fname]
            lines_hash.each do |line, _executions|
              # add the test name to the map. Multiple tests can execute the same
              # line, so we need to use an array.
              file_map[line.to_i] << desc
            end
          end
        end
      end

      repo_root = VCS.repository_root

      to_run = []
      line_changes.each do |(file, line)|
        full_path = File.join(repo_root, file)
        relative_to_pwd = file
        if repo_root != Dir.pwd
          relative_to_pwd = full_path.sub(Dir.pwd, '').sub(File::SEPARATOR, '')
        end
        # test file changes
        # NOTE: here, `file` is a filename starting from the git path (not necessarily `Dir.pwd`).
        # If the actual test file changed, then we need to run the whole test file again.
        if relative_to_pwd.start_with?(*Covet.test_directories)
          if relative_to_pwd.start_with?("test#{File::SEPARATOR}") && relative_to_pwd.end_with?('_test.rb', '_spec.rb')
            to_run << [file, full_path, line] unless to_run.find { |ary| ary.first == file && ary[1] == full_path }
            # We have to disable the method filter in this case because we
            # don't know the names of the methods in this file.
            options[:disable_test_method_filter] = true
          elsif relative_to_pwd.start_with?("spec#{File::SEPARATOR}") && relative_to_pwd.end_with?('_test.rb', '_spec.rb')
            to_run << [file, full_path, line] unless to_run.find { |ary| ary.first == file && ary[1] == full_path }
            # We have to disable the method filter in this case because we
            # don't know the names of the methods in this file.
            options[:disable_test_method_filter] = true
          end
          next
        end
        # library code changes
        cov_map[full_path][line].each do |desc|
          to_run << [file, desc, line] unless to_run.find { |ary| ary.first == file && ary[1] == desc }
        end
      end
      changes_to_app_load = to_run.select { |ary| ary[1] == 'base' }
      changes_to_app_load.delete_if do |file_change, desc, line|
        # FIXME: figure out why I have to do `line + 1`
        to_run.find { |ary| ary[0] == file_change && ary[1] != 'base' && ary[2] == line + 1 }
      end
      must_run_all_test_files = false
      if changes_to_app_load.any?
        to_run = all_test_files
        must_run_all_test_files = true
      else
        to_run.delete_if { |ary| ary[1] == 'base' }
      end

      # execute or print run list
      if options[:exec_run_list]
        if to_run.empty?
          puts "# No test cases to run"
        else
          cmdline = Covet.cmdline_for_run_list(to_run, :all_test_files => must_run_all_test_files)
          puts cmdline
          Kernel.exec cmdline
        end
      elsif options[:print_run_list]
        printer = Covet::RunListPrinter.new(
          to_run,
          :must_run_all_test_files => must_run_all_test_files,
          :print_run_list_format => options[:print_run_list_format]
        )
        puts printer.print_str
      end
    end
  end

  module Options
    DEFAULTS = {
      :collect_cmdline => nil,
      :VCS => :git,
      :revision => :last_commit,
      :test_order => :random_seeded, # one of [:random_seeded, :random, or :ordered]
      :test_runner => :minitest, # ENV['COVET_TEST_RUNNER']
      :exec_run_list => false,
      :disable_test_method_filter => false,
      :print_run_list => true,
      :print_run_list_format => :list,
      :print_collection_stats => false, # TODO: use
      :ignore_changed_files => [],
      :collect_gem_whitelist => [], # ENV['COVET_GEM_WHITELIST']
      :debug => false, # TODO: use
      :verbose => 0, # TODO: levels 0, 1, 2, maybe?
    }.freeze

    # @return Hash
    def self.parse!(argv)
      options = DEFAULTS.dup

      OptionParser.new do |opts|
        opts.banner = "Usage: covet [options]"
        opts.separator ""
        opts.separator "Specific options:"

        opts.on('-c', '--collect CMDLINE', 'collect coverage information for test run of given cmdline') do |cmdline|
          options[:collect_cmdline] = cmdline
        end
        opts.on('--whitelist-gems GEMS', Array, 'whitelist given gems for collection phase') do |gems|
          options[:collect_gem_whitelist] = gems
          gems.each { |gem| CollectionFilter.whitelist_gem(gem) }
        end
        opts.on('-f', '--print-fmt FMT', "Format run list - 'list' (default), 'test-runner' or 'json'") do |fmt|
          case fmt
          when 'list', 'test-runner', 'json'
            options[:print_run_list_format] = fmt.intern
          else
            raise OptionParser::InvalidArgument,
              "Valid values: 'list', 'test-runner', 'json'"
          end
        end
        opts.on('-e', '--exec', 'Execute run list') do
          options[:print_run_list] = false
          options[:exec_run_list] = true
        end
        opts.on('--ignore-changed-files FILES', Array, 'Ignore specified files that have changed in your VCS') do |files|
          options[:ignore_changed_files] = files.map { |file| Utils.convert_to_absolute_paths!(file, :allow_globs => true) }.flatten
        end
        opts.on('--disable-method-filter', 'When executing run list, run all test methods for each file') do
          options[:disable_test_method_filter] = true
        end
        opts.on('-r', '--revision REVISION', 'VCS Revision (defaults to last commit)') do |rev|
          options[:revision] = rev
        end
        opts.on('-t', '--test-runner RUNNER') do |runner|
          begin
            Covet.test_runner = runner
          rescue ArgumentError => e
            Kernel.abort "Error: #{e.message}"
          end
          options[:test_runner] = runner.intern
        end
        #opts.on('-o', '--test-order ORDER', 'Specify test order for collection phase.') do |order|
          #begin
            #Covet.test_order = order.to_s
          #rescue ArgumentError => e
            #Kernel.abort "Error: #{e.message}"
          #end
        #end
        opts.on_tail('-v', '--version', 'Show covet version') do
          puts VERSION
          Kernel.exit
        end
        opts.on('-h', '--help', 'Show this message') do
          puts opts
          Kernel.exit
        end
      end.parse!(argv)

      options
    end
  end
end
