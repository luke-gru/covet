require 'optparse'
require_relative 'log_file'
require_relative 'collection_filter'
require_relative 'version'

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

      revision = options[:revision]
      line_changes = nil # establish scope
      begin
        line_changes = LineChangesVCS.changes_since(revision)
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
        puts "# No changes since #{revision}. You can specify the #{options[:VCS]} revision using the --revision option."
        Kernel.exit
      end

      cov_map = Hash.new { |h, file| h[file] = Hash.new { |i, line| i[line] = [] } }
      logfile = LogFile.new(:mode => 'r')

      if logfile.file_exists?

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
              next
            end

            if args[0] == 'stats' # last value logged
              run_stats.update(args.last)
              next
            end

            desc = args[0]
            delta = args[1]
            next if delta.nil? # no coverage difference
            #stats = args[2]

            delta.each_pair do |fname, lines_hash|
              file_map = cov_map[fname]
              lines_hash.each do |line, _executions|
                # add the test name to the map. Multiple tests can execute the same
                # line, so we need to use an array.
                file_map[line.to_i] << desc
              end
            end
          end
        end

        git_repo = VCS::Git.find_git_repo_path!

        to_run = []
        line_changes.each do |(file, line)|
          full_path = File.join(git_repo, file)
          relative_to_pwd = file
          if git_repo != Dir.pwd
            relative_to_pwd = full_path.sub(Dir.pwd, '').sub(File::SEPARATOR, '')
          end
          # NOTE: here, `file` is a filename starting from the GIT path (not necessarily `Dir.pwd`)
          # if the actual test files changed, then we need to run the whole file again.
          if relative_to_pwd.start_with?(*Covet.test_directories)
            if relative_to_pwd.start_with?("test#{File::SEPARATOR}") && relative_to_pwd.end_with?('_test.rb', '_spec.rb')
              to_run << [file, full_path] unless to_run.include?([file, full_path])
              # We have to disable the method filter in this case because we
              # don't know the method names of all these methods in this file.
              # TODO: save this information in the coverage log file and use it here.
              options[:disable_test_method_filter] = true
            elsif relative_to_pwd.start_with?("spec#{File::SEPARATOR}") && relative_to_pwd.end_with?('_test.rb', '_spec.rb')
              to_run << [file, full_path] unless to_run.include?([file, full_path])
              # We have to disable the method filter in this case because we
              # don't know the method names of all these methods in this file.
              # TODO: save this information in the coverage log file and use it here.
              options[:disable_test_method_filter] = true
            end
            next
          end
          # library code changes
          cov_map[full_path][line].each do |desc|
            to_run << [file, desc] unless to_run.include?([file, desc])
          end
        end
        if ENV['COVET_INVERT_RUN_LIST'] == '1' # NOTE: for debugging covet only
          to_run_fnames = to_run.map { |(_file, desc)| desc.split('#').first }.flatten.uniq
          all_fnames = Dir.glob("{#{Covet.test_directories.join(',')}}/**/*_{test,spec}.rb").to_a.map { |fname| File.expand_path(fname, Dir.pwd) }
          to_run = (all_fnames - to_run_fnames).map { |fname| [fname, "#{fname}##{fname}"] }.sort_by do |ary|
            ary[1].split('#').first
          end
        end
        if options[:exec_run_list]
          if to_run.empty?
            puts "# No test cases to run"
          else
            cmdline = Covet.cmdline_for_run_list(to_run)
            puts cmdline
            Kernel.exec cmdline
          end
        elsif options[:print_run_list]
          if to_run.empty?
            puts "# No test cases to run"
          else
            if options[:print_run_list_format] == :"test-runner"
              puts Covet.cmdline_for_run_list(to_run)
            else
              # TODO: show not just the files but also the methods in each file
              puts "You need to run:"
              to_run.uniq! { |(_file, desc)| desc.split('#').first }
              to_run.each do |(_file, desc)|
                puts " - #{desc.split('#').first}"
              end
            end
          end
        end
      else
        Kernel.abort "Error: The coverage log file doesn't exist.\n" \
          "You need to collect info first with 'covet -c $TEST_CMD'\n" \
          "Ex: covet -c \"rake test\""
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
      :print_run_list_format => :simple,
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
        opts.on('-f', '--print-fmt FMT', "Format run list - 'simple' (default) or 'test-runner'") do |fmt|
          case fmt
          # TODO: add 'json' format to dump run list in JSON
          when 'simple', 'test-runner'
            options[:print_run_list_format] = fmt.intern
          else
            raise OptionParser::InvalidArgument,
              "Valid values: 'simple', 'test-runner'"
          end
        end
        opts.on('-e', '--exec', 'Execute run list') do
          options[:print_run_list] = false
          options[:exec_run_list] = true
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
