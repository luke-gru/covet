require 'json'

module Covet
  # Used to format the printed output of the run list, when printing instead
  # of executing the run list.
  class RunListPrinter
    def initialize(to_run, options = {})
      @to_run = to_run # @var Array
      @must_run_all_test_files = options[:must_run_all_test_files]
      @print_format = options[:print_run_list_format]
    end

    def print_str
      if @to_run.empty?
        return print_empty_str
      end
      if @must_run_all_test_files
        return print_all_str
      end
      print_run_list_str
    end

    private

      def print_empty_str
        case @print_format
        when :list, :'test-runner'
          '# No test cases to run'
        when :json
          JSON.dump({'test_files' => [], 'meta' => {}})
        else
          raise "invalid run list format: '#{@print_format}'"
        end
      end

      def print_all_str
        case @print_format
        when :list
          'You need to run every test file due to change(s) to line(s) that run on application load.'
        when :'test-runner'
          Covet.cmdline_for_run_list(@to_run, :all_test_files => true)
        when :json
          JSON.dump({'test_files' => @to_run, 'meta' => { 'all_files' => true }})
        else
          raise "invalid run list format: '#{@print_format}'"
        end
      end

      def print_run_list_str
        case @print_format
        when :list
          ret = ['You need to run:']
          # TODO: show not just the files but also the methods in each file
          to_run = @to_run.map { |(_file, desc, _)| desc.split('#').first }.uniq
          to_run.each do |fname|
            ret << " - #{fname}"
          end
          ret.join("\n")
        when :'test-runner'
          Covet.cmdline_for_run_list(@to_run, :all_test_files => false)
        when :json
          JSON.dump({'test_files' => @to_run.map { |_file, desc, _| desc.split('#').first }.uniq, 'meta' => {}})
        else
          raise "invalid run list format: '#{@print_format}'"
        end
      end
  end
end
