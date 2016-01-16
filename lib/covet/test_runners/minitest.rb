require 'rake/testtask'

module Covet
  module TestRunners
    module Minitest
      @hooked = false
      @create_collection_file_on_exit = true
      class << self
        attr_accessor :create_collection_file_on_exit
      end

      def self.hook_into_test_methods!
        if @hooked
          warn "Warning - Covet.register_coverage_collection! called multiple times"
          return
        end
        gem 'minitest'
        begin
          require 'minitest' # minitest 5
        rescue LoadError
          require 'minitest/unit' # minitest 4
        end
        version = defined?(::Minitest::VERSION) ?
          ::Minitest::VERSION : # v >= 5
          ::Minitest::Unit::VERSION # v < 5

        if version.to_f >= 5.0
          ::Minitest.after_run do
            after_t = Time.now
            diff_t = after_t - ::Minitest::Runnable.covet_start_time
            time_taken = sprintf("%.2f", diff_t)
            Covet.log_collection << ['stats', {
              :time_taken => time_taken,
              :files_filtered => CollectionFilter.files_filtered,
            }]
            if Covet::TestRunners::Minitest.create_collection_file_on_exit
              Covet.log_collection.finish!
            else
              $stderr.puts "Covet: skipped writing to collection file"
            end
          end

          if ::Minitest::Runnable.respond_to?(:run_one_method) # minitest > 5.0.8
          ::Minitest::Runnable.class_eval do
            @@covet_run_num = 0
            @@covet_skips = 0
            @@covet_failures = 0
            @@covet_start_time = nil

            class << self
              def covet_start_time
                @@covet_start_time
              end

              alias :covet_old_run_one_method :run_one_method

              def run_one_method(klass, method_name, reporter)
                # first run, collect coverage 'base' coverage information
                # (coverage information for before any tests get run).
                if @@covet_run_num == 0
                  @@covet_start_time = Time.now
                  base_coverage = CovetCoverage.peek_result
                  base_coverage = Covet.normalize_coverage_info(base_coverage)
                  if base_coverage.empty?
                    warn "Warning - covet is not properly set up, as it must be required " \
                      "before other libraries to work correctly.\nTry adding\n  require 'covet'\n" \
                      "to the top of your test helper file."
                  end
                  Covet::BASE_COVERAGE.update base_coverage
                  Covet.log_collection << ['base', base_coverage, {
                    :version => Covet::VERSION,
                    :options => Covet.options,
                    :seed => Random::DEFAULT.seed,
                  }]
                end

                @@covet_run_num += 1
                file = nil
                begin
                  file = klass.instance_method(method_name).source_location[0]
                rescue
                  warn "\nWarning - Skipping collecting test coverage for method #{klass}##{method_name}\n"
                  return
                end

                before = CovetCoverage.peek_result

                # Run test method
                before_t = Time.now
                result = covet_old_run_one_method(klass, method_name, reporter)
                after_t = Time.now

                summary_reporter = result.first
                skips = summary_reporter.results.select(&:skipped?).size

                # test was skipped, don't record coverage info
                if @@covet_skips != skips
                  @@covet_skips = skips
                  @@covet_failures += 1
                  return result
                end

                # test failed, don't record coverage info
                failures = summary_reporter.results.select(&:failures).size
                if @@covet_failures != failures
                  @@covet_failures = failures
                  return result
                end

                after = CovetCoverage.peek_result

                before_orig = Covet.normalize_coverage_info(before)
                if Covet::BASE_COVERAGE.any?
                  before = Covet.diff_coverages(Covet::BASE_COVERAGE, before_orig)
                end

                after_orig = Covet.normalize_coverage_info(after)
                after = Covet.diff_coverages(before_orig, after_orig)
                if @@covet_run_num > 1
                  if [:random_seeded, :ordered].include?(Covet.options[:test_order])
                    Covet::BASE_COVERAGE.update(after_orig)
                  end
                end

                if after == before
                  after = nil
                end
                Covet.log_collection << ["#{file}##{method_name}", after, {
                  :time => sprintf("%.2f", after_t - before_t),
                }]
                result
              # NOTE: if the interrupt is fired outside of `Minitest.run_one_method`, then the
              # collection file gets logged to even on interrupt :(
              rescue Interrupt, SystemExit
                Covet::TestRunners::Minitest.create_collection_file_on_exit = false
                raise
              end

            end
          end
          elsif ::Minitest::Runnable.respond_to?(:run)
            # minitest ~ 5.0.8
            ::Minitest::Runnable.class_eval do
              @@covet_run_num = 0
              @@covet_skips = 0
              @@covet_failures = 0
              @@covet_start_time = nil
              class << self
                def covet_start_time
                  @@covet_start_time
                end

                alias :covet_old_run :run

                def run(reporter, options = {})
                  filter = options[:filter] || '/./'
                  filter = Regexp.new $1 if filter =~ /\/(.*)\//
                  filtered_methods = self.runnable_methods.find_all { |m|
                    filter === m || filter === "#{self}##{m}"
                  }

                  failures = 0
                  with_info_handler reporter do
                    filtered_methods.each do |method_name|

                      # first run, collect coverage 'base' coverage information
                      # (coverage information for before any tests get run).
                      if @@covet_run_num == 0
                        @@covet_start_time = Time.now
                        base_coverage = CovetCoverage.peek_result
                        base_coverage = Covet.normalize_coverage_info(base_coverage)
                        if base_coverage.empty?
                          warn "Warning - covet is not properly set up, as it must be required " \
                            "before other libraries to work correctly.\nTry adding\n  require 'covet'\n" \
                            "to the top of your test helper file."
                        end
                        Covet::BASE_COVERAGE.update base_coverage
                        Covet.log_collection << ['base', base_coverage, {
                          :version => Covet::VERSION,
                          :options => Covet.options,
                          :seed => Random::DEFAULT.seed,
                        }]
                      end

                      @@covet_run_num += 1
                      file = nil
                      begin
                        file = instance_method(method_name).source_location[0]
                      rescue
                        warn "\nWarning - Skipping collecting test coverage for method #{klass}##{method_name}\n"
                        next
                      end

                      before = CovetCoverage.peek_result

                      # Run test method
                      before_t = Time.now
                      result = self.new(method_name).run
                      after_t = Time.now
                      raise "#{self}#run _must_ return self" unless self === result
                      ret = reporter.record result

                      if result.skipped?
                        @@covet_skips += 1
                        next
                      end

                      # test failed, don't record coverage info
                      new_failures = result.failures.size
                      if new_failures > failures
                        @@covet_failures += 1
                        failures += 1
                        next
                      end

                      after = CovetCoverage.peek_result

                      before_orig = Covet.normalize_coverage_info(before)
                      if Covet::BASE_COVERAGE.any?
                        before = Covet.diff_coverages(Covet::BASE_COVERAGE, before_orig)
                      end

                      after_orig = Covet.normalize_coverage_info(after)
                      after = Covet.diff_coverages(before_orig, after_orig)
                      if @@covet_run_num > 1
                        if [:random_seeded, :ordered].include?(Covet.options[:test_order])
                          Covet::BASE_COVERAGE.update(after_orig)
                        end
                      end

                      if after == before
                        after = nil
                      end

                      Covet.log_collection << ["#{file}##{method_name}", after, {
                        :time => sprintf("%.2f", after_t - before_t),
                      }]

                      ret
                    end
                  end
                # NOTE: if the interrupt is fired outside of `Minitest.run_one_method`, then the
                # collection file gets logged to even on interrupt :(
                rescue Interrupt, SystemExit
                  Covet::TestRunners::Minitest.create_collection_file_on_exit = false
                  raise
                end

              end
            end
          else
            raise "Minitest version #{::Minitest::VERSION rescue '?'} not supported."
          end
        elsif defined?(::Minitest::Unit::TestCase) && ::Minitest::Unit::TestCase.method_defined?(:run)
          ::Minitest::Unit.after_tests do
            after_t = Time.now
            diff_t = after_t - ::Minitest::Unit::TestCase.covet_start_time
            time_taken = sprintf("%.2f", diff_t)
            Covet.log_collection << ['stats', {
              :time_taken => time_taken,
              :files_filtered => CollectionFilter.files_filtered,
            }]
            if Covet::TestRunners::Minitest.create_collection_file_on_exit
              Covet.log_collection.finish!
            else
              $stderr.puts "Covet: skipped writing to collection file"
            end
          end
          ::Minitest::Unit::TestCase.class_eval do
            @@covet_run_num = 0
            @@covet_skips = 0
            @@covet_failures = 0
            @@covet_start_time = nil

            class << self
              def covet_start_time
                @@covet_start_time
              end
            end

            alias :covet_old_run :run

            def run(runner)
              # first run, collect coverage 'base' coverage information
              # (coverage information for before any tests get run).
              if @@covet_run_num == 0
                @@covet_start_time = Time.now
                base_coverage = CovetCoverage.peek_result
                base_coverage = Covet.normalize_coverage_info(base_coverage)
                if base_coverage.empty?
                  warn "Warning - covet is not properly set up, as it must be required " \
                    "before other libraries to work correctly.\nTry adding\n  require 'covet'\n" \
                    "to the top of your test helper file."
                end
                Covet::BASE_COVERAGE.update base_coverage
                Covet.log_collection << ['base', base_coverage, {
                  :version => Covet::VERSION,
                  :options => Covet.options,
                  :seed => Random::DEFAULT.seed,
                }]
              end

              @@covet_run_num += 1
              file = nil
              begin
                file = method(self.__name__).source_location[0]
              rescue
                warn "\nWarning - Skipping collecting test coverage for method #{self.class}##{self.__name__}\n"
                return
              end
              before = CovetCoverage.peek_result

              # Run test method
              before_t = Time.now
              result = covet_old_run(runner)
              after_t = Time.now

              skips = runner.skips

              # test was skipped, don't record coverage info
              if @@covet_skips != skips
                @@covet_skips = skips
                @@covet_failures += 1
                return result
              end

              # test failed, don't record coverage info
              failures = runner.failures
              if @@covet_failures != failures
                @@covet_failures = failures
                return result
              end

              after = CovetCoverage.peek_result

              before_orig = Covet.normalize_coverage_info(before)
              if Covet::BASE_COVERAGE.any?
                before = Covet.diff_coverages(Covet::BASE_COVERAGE, before_orig)
              end

              after_orig = Covet.normalize_coverage_info(after)
              after = Covet.diff_coverages(before_orig, after_orig)
              if @@covet_run_num > 1
                if [:random_seeded, :ordered].include?(Covet.options[:test_order])
                  Covet::BASE_COVERAGE.update(after_orig)
                end
              end

              if after == before
                after = nil
              end
              Covet.log_collection << ["#{file}##{self.__name__}", after, {
                :time => sprintf("%.2f", after_t - before_t),
              }]
              result
            # NOTE: if the interrupt is fired outside of `Minitest::Unit::TestCase.run`, then the
            # collection file gets logged even on interrupt :(
            rescue Interrupt, SystemExit
              Covet::TestRunners::Minitest.create_collection_file_on_exit = false
              raise
            end

          end
        else
          raise "Minitest version #{::Minitest::VERSION rescue '?'} not supported."
        end
        @hooked = true
      end

      def self.cmdline_for_run_list(run_list, options = {})
        files = run_list.map { |double| double[1].split('#').first }
        files.uniq!

        files_str = files.map { |fname| %Q("#{fname}") }.join(' ')
        rake_testtask = Rake::TestTask.new
        rake_loader_str = rake_testtask.rake_loader
        rake_include_arg = %Q(-I"#{rake_testtask.rake_lib_dir}")

        cmd = %Q(ruby -I"test" -I"lib" #{rake_include_arg} "#{rake_loader_str}" ) +
          files_str

        unless Covet.options[:disable_test_method_filter] || options[:all_test_files]
          test_methods = run_list.map { |double| double[1].split('#').last }
          test_methods.uniq!
          test_methods_regex = Regexp.union(test_methods)
          cmd << %Q( "-n #{test_methods_regex.inspect}")
        end
        cmd
      end
    end
  end
end
