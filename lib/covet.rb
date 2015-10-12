require 'json'
require 'set'

require_relative 'covet/version'
if defined?(Coverage) && Coverage.respond_to?(:peek_result)
  CovetCoverage = Coverage
else
  begin
    require_relative 'covet_coverage.so'
  rescue Exception # re-raised
    $stderr.puts "Error loading 'covet' C extension.\n" \
      "Please report this bug along with a backtrace. Thanks :)"
    raise
  end
end
require_relative 'covet/collection_filter'
require_relative 'covet/line_changes_vcs'
require_relative 'covet/cli'

require 'debugger' if ENV['COVET_DEBUG']

module Covet
  COLLECTION_LOGS = []

  def self.vcs=(vcs)
    @vcs = vcs.intern
    if @vcs != :git
      raise NotImplementedError, "Can only use git as the VCS for now."
    end
  end
  def self.vcs; @vcs; end
  self.vcs = :git # default

  def self.test_runner=(runner)
    @test_runner = runner.intern
    require_relative "covet/test_runners/#{runner}"
  rescue LoadError
    raise ArgumentError, "invalid test runner given: '#{runner}'. " \
      "Expected 'rspec' or 'minitest'"
  end
  def self.test_runner; @test_runner; end
  self.test_runner = :minitest # default

  def self.test_directories=(*dirs)
    dirs = dirs.flatten
    dirs.each do |dir|
      unless Dir.exist?(dir)
        raise Errno::ENOENT, %Q(invalid directory given: "#{dir}" ) +
          %Q{("#{File.join(Dir.pwd, dir)}")}
      end
    end
    @test_directories = dirs
  end
  def self.test_directories; @test_directories.dup; end
  self.test_directories = []
  if Dir.exist?('test')
    self.test_directories = self.test_directories + ['test']
  end
  if Dir.exist?('spec')
    self.test_directories = self.test_directories + ['spec']
  end

  def self.register_coverage_collection!
    # stdlib Coverage can't run at the same time as CovetCoverage or
    # bad things will happen
    if defined?(Coverage) && !Coverage.respond_to?(:peek_result)
      Coverage.stop rescue nil
    end
    CovetCoverage.start # needs to be called before any application code gets required
    Covet::TestRunners.const_get(
      @test_runner.to_s.capitalize
    ).hook_into_test_methods!
  end

  # @return String
  def self.cmdline_for_run_list(run_list)
    Covet::TestRunners.const_get(
      @test_runner.to_s.capitalize
    ).cmdline_for_run_list(run_list)
  end

  # Diff coverage information for before `block` ran, and after `block` ran
  # for the codebase in its current state.
  # @return Array
  def self.diff_coverage_for(&block)
    before = CovetCoverage.peek_result
    block.call
    after = CovetCoverage.peek_result
    [CollectionFilter.filter(before), CollectionFilter.filter(after)]
  end

  # Generates a mapping of filenames to the lines and test methods that
  # caused the changes.
  # @return Hash, example:
  #   { "/home/me/workspace/myproj/myproj.rb" => { 1 => ['test_method_that_caused_changed']} }
  def self.generate_run_list_for_method(before, after, options = {})
    cov_map = Hash.new { |h, file| h[file] = Hash.new { |i, line| i[line] = [] } }
    delta = diff_coverages(before, after)
    delta.each_pair do |file, lines|
      file_map = cov_map[file]

      lines.each_with_index do |val, i|
        # skip lines that weren't executed
        next unless val && val > 0

        # add the test name to the map. Multiple tests can execute the same
        # line, so we need to use an array.
        file_map[i + 1] << (options[:method_name] || '???').to_s
      end
    end
    cov_map
  end

  # @return Hash
  def self.diff_coverages(before, after)
    after.each_with_object({}) do |(file_name, line_cov), res|
      before_line_cov = before[file_name] || []

      # skip arrays that are exactly the same
      next if before_line_cov == line_cov

      # find the coverage difference
      cov = line_cov.zip(before_line_cov).map do |line_after, line_before|
        if line_after && line_before
          line_after - line_before
        else
          line_after
        end
      end

      # add the "diffed" coverage to the hash
      res[file_name] = cov
    end
  end
end

if ENV['COVET_COLLECT'] == '1'
  Covet.register_coverage_collection!
end
