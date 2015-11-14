require 'rake/testtask'

module Covet
  module TestRunners
    module Minitest
      @hooked = false

      def self.hook_into_test_methods!
        if @hooked
          warn "Warning - Covet.register_coverage_collection! called multiple times"
          return
        end
        gem 'minitest'
        require 'minitest'

        ::Minitest.after_run do
          Covet.log_collection.finish!
        end

        ::Minitest::Runnable.class_eval do
          @@run_num = 0
          @@skips = 0
          @@failures = 0

          class << self
            alias :covet_old_run_one_method :run_one_method

            def run_one_method(klass, method_name, reporter)
              # first run, collect coverage 'base' coverage information
              # (coverage information for before any tests get run).
              if @@run_num == 0
                base_coverage = CovetCoverage.peek_result
                base_coverage = Covet.normalize_coverage_info(base_coverage)
                if base_coverage.empty?
                  warn "Warning - covet is not properly set up, as it must be required " \
                    "before other libraries to properly work.\nIf it isn't already, try " \
                    "adding\n  require 'covet'\nas the first thing in your test helper file."
                end
                Covet::BASE_COVERAGE.update base_coverage
                # TODO: save Random::DEFAULT.seed in run log file if Covet.options[:test_order] == :random_seeded,
                # then we can run the methods in the same order as before.
                Covet.log_collection << ['base', base_coverage]
              end

              @@run_num += 1
              file = nil
              begin
                file = klass.instance_method(method_name).source_location[0]
              rescue
                warn "\nWarning - Skipping collecting test coverage for method #{klass}##{method_name}\n"
                return
              end

              before = CovetCoverage.peek_result

              # Run test method
              result = covet_old_run_one_method(klass, method_name, reporter)

              summary_reporter = result.first
              skips = summary_reporter.results.select(&:skipped?).size

              # test was skipped, don't record coverage info
              if @@skips != skips
                @@skips = skips
                @@failures += 1
                return result
              end

              # test failed, don't record coverage info
              failures = summary_reporter.results.select(&:failures).size
              if @@failures != failures
                @@failures = failures
                return result
              end

              after = CovetCoverage.peek_result

              before_orig = Covet.normalize_coverage_info(before)
              if Covet::BASE_COVERAGE.any?
                before = Covet.diff_coverages(Covet::BASE_COVERAGE, before_orig)
              end

              after_orig = Covet.normalize_coverage_info(after)
              after = Covet.diff_coverages(before_orig, after_orig)
              if @@run_num > 1
                if [:random_seeded, :ordered].include?(Covet.options[:test_order])
                  Covet::BASE_COVERAGE.update(after_orig)
                end
              end

              if after == before
                after = nil
              end
              Covet.log_collection << ["#{file}##{method_name}", after]
              result
            end

          end
        end
        @hooked = true
      end

      def self.cmdline_for_run_list(run_list)
        files = run_list.map { |double| double[1].split('#').first }
        files.uniq!

        files_str = files.map { |fname| %Q("#{fname}") }.join(' ')
        rake_testtask = Rake::TestTask.new
        rake_loader_str = rake_testtask.rake_loader
        rake_include_arg = %Q(-I"#{rake_testtask.rake_lib_dir}")

        cmd = %Q(ruby -I"test" -I"lib" #{rake_include_arg} "#{rake_loader_str}" ) +
          files_str

        unless Covet.options[:disable_test_method_filter]
          test_methods = run_list.map { |double| double[1].split('#').last }
          test_methods.uniq!
          test_methods_regex = Regexp.union(test_methods)
          cmd << " -n #{test_methods_regex.inspect}"
        end
        cmd
      end
    end
  end
end
