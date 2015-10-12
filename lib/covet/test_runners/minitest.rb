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
        ::Minitest::Runnable.class_eval do

          ::Minitest.after_run do
            File.open(File.join(Dir.pwd, 'run_log.json'), 'w') do |f|
              f.write JSON.dump Covet::COLLECTION_LOGS
            end
          end

          class << self
            alias :covet_old_run_one_method :run_one_method

            def run_one_method klass, method_name, reporter
              file = klass.instance_method(method_name).source_location[0]
              before, after = Covet.diff_coverage_for do
                covet_old_run_one_method(klass, method_name, reporter)
              end
              Covet::COLLECTION_LOGS << ["#{file}##{method_name}", before, after]
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
