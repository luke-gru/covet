module Covet
  module TestRunners
    module Minitest
      # TODO: way to unhook it (not sure how to unhook the `Minitest.after_run`) block
      def self.hook_into_test_methods!
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
              before, after = Covet.diff_coverage_for do
                covet_old_run_one_method(klass, method_name, reporter)
              end
              Covet::COLLECTION_LOGS << ["#{klass.name}##{method_name}", before, after]
            end
          end
        end
      end
    end
  end
end
