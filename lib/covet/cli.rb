require 'shellwords'

module Covet
  class CLI
    def initialize(argv)
      @argv = argv
    end

    # TODO: process cmdline options
    #   - specify VCS
    #   - specify `since` got VCS
    #   - specify test runner
    #   - print out filenames only
    #   - print out command for running all files with specified test runner
    #   - run all files that need to be run for specified test runner
    def run
      since = :last_commit
      line_changes = nil
      begin
        line_changes = LineChangesVCS.changes_since(since)
      rescue Rugged::RepositoryError
        abort "#{Dir.pwd} is not a git repository. " \
          "Make sure you're in the project root."
      end
      if line_changes.empty?
        puts "No changes since #{since}"
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
          # TODO: should take project root as parameter, maybe?
          full_path = File.join(Dir.pwd, file)
          cov_map[full_path][line].each do |desc|
            to_run << [file, desc] unless to_run.include?([file, desc])
          end
        end
        if to_run.empty?
          puts "No test cases to run"
        else
          puts "You need to run:"
          to_run.uniq!
          to_run.each do |(file, desc)|
            puts " - #{file} (#{desc.split('#').last})"
          end
        end
      else
        # TODO: usage for collecting
        abort "The coverage log doesn't exist. Need to collect info first."
      end
    end
  end
end
