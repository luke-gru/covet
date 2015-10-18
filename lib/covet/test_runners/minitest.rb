require 'rake/testtask'

module Covet
  module TestRunners
    module Minitest
      @hooked = false

      def self.hook_into_test_methods!
        if @hooked
          warn "Covet.register_coverage_collection! called multiple times"
          return
        end
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

            def run_one_method klass, method_name, reporter
              # first run, collect coverage 'base' coverage information
              # (coverage information for before any tests get run).
              if @@run_num == 0
                base_coverage = CovetCoverage.peek_result
                base_coverage = Covet.normalize_coverage_info(base_coverage)
                Covet::BASE_COVERAGE.update base_coverage
                Covet.log_collection << ['base', base_coverage]
              end

              @@run_num += 1
              begin
                file = klass.instance_method(method_name).source_location[0]
              rescue => e
                return
              end

              before = CovetCoverage.peek_result

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
              before = Covet.normalize_coverage_info(before)
              if Covet::BASE_COVERAGE.any?
                before = Covet.diff_coverages(Covet::BASE_COVERAGE, before)
              end
              after = Covet.normalize_coverage_info(after)
              after = Covet.diff_coverages(before, after)

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
        test_methods = run_list.map { |double| double[1].split('#').last }
        files.uniq!
        test_methods.uniq!

        files_str = files.map { |fname| %Q("#{fname}") }.join(' ')
        test_methods_regex = Regexp.union(test_methods)
        rake_testtask = Rake::TestTask.new
        rake_loader_str = rake_testtask.rake_loader
        rake_include_arg = %Q(-I"#{rake_testtask.rake_lib_dir}")

        %Q(ruby -I"test" -I"lib" #{rake_include_arg} "#{rake_loader_str}" ) +
          %Q(#{files_str} "-n #{test_methods_regex.inspect}")
      end
    end
  end
end
