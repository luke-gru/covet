require 'rspec/core/rake_task'

module Covet
  module TestRunners
    module Rspec
      # TODO: test this
      def self.hook_into_test_methods!
        ::RSpec.configuration.after(:suite) do
          File.open(File.join(Dir.pwd, 'run_log.json'), 'w') do |f|
            f.write JSON.dump Covet::COLLECTION_LOGS
          end
        end

        ::RSpec.configuration.around(:each) do |test|
          before, after = Covet.diff_coverage_for do
            test.call
          end
          rspec_metadata = test.metadata
          # XXX: is this right for all recent versions of rake?
          file = rspec_metadata[:file_path].sub(%r{\A\./}, '') # remove leading './'
          line = rspec_metadata[:line_number]
          Covet::COLLECTION_LOGS << ["#{file}:#{line}", before, after]
        end
      end

      def self.cmdline_for_run_list(run_list)
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
