require 'rake/testtask'
require 'rake/extensiontask'

task :default => [:test]

desc 'Run all tests (default)'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_test.rb'].to_a
  t.verbose = true
end

desc 'compile internal coverage C extension'
Rake::ExtensionTask.new('covet_coverage')
