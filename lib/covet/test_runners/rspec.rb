module Covet
  module TestRunners
    module Rspec
      @hooked = false
      @run_num = 0
      @skips = 0
      @failures = 0

      def self.hook_into_test_methods!
        if @hooked
          warn "Covet.register_coverage_collection! called multiple times"
          return
        end
        require 'rspec'

        ::RSpec.configuration.after(:suite) do
          Covet.log_collection.finish!
        end

        run_num = @run_num
        skips = @skips
        failures = @failures

        ::RSpec.configuration.around(:each) do |test|
          if run_num == 0
            base_coverage = CovetCoverage.peek_result
            base_coverage = Covet.normalize_coverage_info(base_coverage)
            Covet::BASE_COVERAGE.update base_coverage
            Covet.log_collection << ['base', base_coverage]
          end

          run_num += 1

          before = CovetCoverage.peek_result

          test.call

          rspec_metadata = test.metadata

          # TODO: figure out if failed or skipped, and break out of block if it did
          #
          # XXX: is this right for all recent versions of rake?
          file = rspec_metadata[:file_path].sub(%r{\A\./}, '') # remove leading './'
          line = rspec_metadata[:line_number]

          after = CovetCoverage.peek_result
          before = Covet.normalize_coverage_info(before)
          if Covet::BASE_COVERAGE.any?
            before = Covet.diff_coverages(Covet::BASE_COVERAGE, before)
          end
          after = Covet.normalize_coverage_info(after)
          after = Covet.diff_coverages(before, after)

          if after == before
            after = nil
          end

          Covet.log_collection << ["#{file}:#{line}", after]
        end
        @hooked = true
      end

      def self.cmdline_for_run_list(run_list)
        require 'rspec/core/rake_task'
        files = run_list.map { |double| double[1] }
        files.uniq!
        file_list = files.join(' ')
        old_spec_env = ENV['SPEC']
        begin
          ENV['SPEC'] = file_list
          rspec_rake_task = RSpec::Core::RakeTask.new(:spec) do |t|
          end
        ensure
          ENV['SPEC'] = old_spec_env
        end
        # XXX: is this right for all recent versions of rake?
        rspec_rake_task.send(:spec_command)
      end
    end
  end
end
