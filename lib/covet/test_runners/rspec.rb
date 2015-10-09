module Covet
  module TestRunners
    module Rspec
      # TODO: test this
      # TODO: way to unhook it (not sure how to unhook the `Minitest.after_run`) block
      def self.hook_into_test_methods!
        RSpec.configuration.after(:suite) do
          File.open(File.join(Dir.pwd, 'run_log.json'), 'w') do |f|
            f.write JSON.dump Covet::COLLECTION_LOGS
          end
        end

        RSpec.configuration.around(:example) do |example|
          before, after = Covet.diff_coverage_for do
            example.call
          end
          Covet::COLLECTION_LOGS << [example.full_description, before, after]
        end
      end
    end
  end
end
