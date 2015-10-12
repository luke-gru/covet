require 'optparse'

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
        Covet.register_coverage_collection!
        cmd = options[:collect_cmdline]
        puts "Collecting coverage information for each test method..."
        puts cmd
        pid = fork do
          # execute `cmd` with coverage information hooks on. `cmd` should
          # be a minitest or rspec commandline.
          exec cmd
        end
        if pid
          exitstatus = Process.waitpid(pid)
          exit exitstatus
        end
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
      run_log_fname = File.join(Dir.pwd, 'run_log.json')

      if File.exist?(run_log_fname)
        File.open(run_log_fname) do |f|
          # Read in the coverage info
          JSON.parse(f.read).each do |args|
            if args.length == 3 # for Minitest
              desc = args.first
            else
              raise "missing 3rd argument in json log"
            end

            before, after = args.last(2)

            # calculate the per test coverage
            delta = Covet.diff_coverages(before, after)

            delta.each_pair do |file, lines|
              file_map = cov_map[file]
              lines.each_with_index do |val, i|
                # skip lines that weren't executed
                next unless val && val > 0
                # add the test name to the map. Multiple tests can execute the same
                # line, so we need to use an array.
                file_map[i + 1] << desc
              end
            end
          end
        end
        to_run = []
        line_changes.each do |(file, line)|
          if file.start_with?(*Covet.test_directories)
            if file.start_with?("test#{File::PATH_SEPARATOR}") && file.end_with?('_test.rb')
              to_run << [file, file] unless to_run.include?([file, file])
            elsif file.start_with?("spec#{File::PATH_SEPARATOR}") && file.end_with?('_spec.rb')
              to_run << [file, file] unless to_run.include?([file, file])
            end
            next
          end
          full_path = File.join(Dir.pwd, file)
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
              to_run.uniq!
              to_run.each do |(file, desc)|
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

      opts_parser = OptionParser.new do |opts|
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
