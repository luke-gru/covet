require 'json'
require 'set'

if defined?(Coverage)
  Coverage.stop rescue nil
end
require_relative 'covet_coverage.so'
require_relative 'covet/collection_filter'

require 'debugger' if ENV['COVET_DEBUG']
CovetCoverage.start # needs to be called before any application code gets required

module Covet
  COLLECTION_LOGS = []

  def self.vcs=(vcs)
    @vcs = vcs.intern
    if @vcs != :git
      raise NotImplementedError, "Can only use git as the VCS for now."
    end
  end
  self.vcs = :git # default

  def self.test_runner=(runner)
    @test_runner = runner.intern
    require_relative "covet/test_runners/#{runner}"
  rescue LoadError
    raise ArgumentError, "invalid test runner given: #{runner}. " \
    "Expected 'rspec' or 'minitest'"
  end
  self.test_runner = :minitest # default

  # Diff coverage information for before `block` ran, and after `block` ran
  # for the codebase in its current state.
  # @return Array
  def self.diff_coverage_for(&block)
    before = CovetCoverage.peek_result
    block.call
    after = CovetCoverage.peek_result
    [CollectionFilter.filter(before), CollectionFilter.filter(after)]
  end

  # Generates a mapping of filenames to the lines that test methods that
  # caused their changes.
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

  private

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
