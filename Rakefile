require 'rake/testtask'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rake/clean'
require 'wwtd/tasks'

task :default => [:tests_and_specs]
task :travis => [:wwtd] # run travis builds locally

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_test.rb'].to_a
  t.verbose = true
  if t.respond_to?(:description=)
    t.description = 'Run all minitest tests'
  end
end

desc 'Run all rspec specs'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  t.verbose = true
end

desc 'Run minitest and rspec tests (default)'
task :tests_and_specs => [:test, :spec]

desc 'compile internal coverage C extension'
Rake::ExtensionTask.new('covet_coverage')

desc 'recompile internal coverage C extension'
task :recompile => [:clobber, :compile, :tests_and_specs]

# for rake:clobber
CLOBBER.include(
  'run_log.json',
  'run_log_index.json',
  'ext/covet_coverage/*.{so,o}',
  'ext/covet_coverage/Makefile',
  'gemfiles/*.lock',
)
