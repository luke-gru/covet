require 'optparse'
require_relative 'log_file'

module Covet
  class CLI
    def initialize(argv)
      @argv = argv
    end

    # TODO: process cmdline options
    #   - specify VCS [ ]
    #   - specify `revision` for VCS [x]
    #   - specify test runner [x]
    #   - print out filenames only [x]
    #   - print out command for running all files with specified test runner [x]
    #   - run all files that need to be run for specified test runner [x]
    def run
      options = nil
      begin
        options = Options.parse!(@argv)
      rescue OptionParser::InvalidArgument, OptionParser::InvalidOption => e
        abort "Error: #{e.message}"
      end

      if options[:collect_cmdline] && !options[:collect_cmdline].empty?
        cmd = options[:collect_cmdline]
        puts "Collecting coverage information for each test method..."
        puts cmd
        exec("COVET_COLLECT=1 #{cmd}")
      end

      revision = options[:revision]
      line_changes = nil # establish scope
      begin
        line_changes = LineChangesVCS.changes_since(revision)
      rescue Rugged::RepositoryError
        abort "Error: #{Dir.pwd} is not a git repository. " \
          "Make sure you're in the project root."
      rescue Rugged::Error, Rugged::InvalidError, TypeError
        abort "Error: #{options[:revision]} is not a valid revision reference in #{options[:VCS]}"
      end
      if line_changes.empty?
        puts "# No changes since #{revision}"
        exit
      end

      cov_map = Hash.new { |h, file| h[file] = Hash.new { |i, line| i[line] = [] } }
      logfile = Covet::LogFile.new

      if logfile.file_exists?

        # Read in the coverage info
        logfile.load_each_buf! do |buf|
          buf.each do |args|
            if args[0] == 'base'
              next
            end
            desc = args.first
            delta = args.last
            next if delta.nil?

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

        git_repo = Covet::VCS::Git.find_git_repo_path!

        to_run = []
        line_changes.each do |(file, line)|
          if file.start_with?(*Covet.test_directories)
            if file.start_with?("test#{File::SEPARATOR}") && file.end_with?('_test.rb')
              to_run << [file, file] unless to_run.include?([file, file])
            elsif file.start_with?("spec#{File::SEPARATOR}") && file.end_with?('_spec.rb')
              to_run << [file, file] unless to_run.include?([file, file])
            end
            next
          end
          full_path = File.join(git_repo, file)
          cov_map[full_path][line].each do |desc|
            to_run << [file, desc] unless to_run.include?([file, desc])
          end
        end
        if options[:exec_run_list]
          if to_run.empty?
            puts "# No test cases to run"
          else
            cmdline = Covet.cmdline_for_run_list(to_run)
            puts cmdline
            exec cmdline
          end
        elsif options[:print_run_list]
          if to_run.empty?
            puts "# No test cases to run"
          else
            if options[:print_run_list_format] == :"test-runner"
              puts Covet.cmdline_for_run_list(to_run)
            else
              puts "You need to run:"
              to_run.uniq! { |(_file, desc)| desc.split('#').first }
              to_run.each do |(_file, desc)|
                puts " - #{desc.split('#').first}"
              end
            end
          end
        end
      else
        # TODO: usage for collecting
        abort "Error: The coverage log doesn't exist. Need to collect info first."
      end
    end
  end

  module Options
    DEFAULTS = {
      :collect_cmdline => nil,
      :VCS => :git,
      :revision => :last_commit,
      :test_runner => :minitest,
      :exec_run_list => false,
      :print_run_list => true,
      :print_run_list_format => :simple,
      :debug => false,
      :verbose => 0, # TODO: levels 0, 1, 2, maybe?
    }

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
        opts.on('-r', '--revision REVISION', 'VCS Revision (defaults to last commit)') do |rev|
          options[:revision] = rev
        end
        opts.on('-t', '--test-runner RUNNER') do |runner|
          begin
            Covet.test_runner = runner
          rescue ArgumentError => e
            abort "Error: #{e.message}"
          end
          options[:test_runner] = runner.intern
        end
        opts.on_tail('-v', '--version', 'Show covet version') do
          puts VERSION
          exit
        end
        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit
        end
      end.parse!(argv)

      options
    end
  end
end
