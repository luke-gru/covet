require 'rake/testtask'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rake/clean'
require 'wwtd/tasks'

desc 'Run unit and integration tests'
task :default => [:unit_tests, :integration_tests]

desc 'Run minitest and rspec unit tests'
task :unit_tests => [:minitest_unit_tests, :rspec_unit_tests]

desc 'run minitest unit tests'
task :test => [:minitest_unit_tests] # for `wwtd`, which runs `rake test` by default

task :travis => [:clobber, :compile, :wwtd, :rspec_unit_tests, :integration_tests] # run travis builds locally

Rake::TestTask.new(:minitest_unit_tests) do |t|
  t.test_files = FileList['test/*_test.rb'].to_a
  t.verbose = true
  if t.respond_to?(:description=)
    t.description = 'Run all minitest unit tests'
  end
end

desc 'Run all rspec unit tests'
RSpec::Core::RakeTask.new(:rspec_unit_tests) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  t.verbose = true
end

Rake::TestTask.new(:integration_tests) do |t|
  t.test_files = FileList['test/integration/**/*_test.rb'].to_a
  t.verbose = true
  if t.respond_to?(:description=)
    t.description = 'Run all integration tests'
  end
end

desc 'compile internal coverage C extension'
Rake::ExtensionTask.new('covet_coverage') do |ext| # rake compile
  ext.lib_dir = 'lib' # output covet_coverage.so to 'lib' directory
end

desc 'recompile internal coverage C extension'
task :recompile => [:clobber, :compile, :default]

# for rake:clobber
CLOBBER.include(
  'run_log.json',
  'run_log_index.json',
  'lib/*.{so,o,bundle}',
  'ext/covet_coverage/Makefile',
  'gemfiles/*.lock',
)
