require_relative 'covet/version'
if defined?(Coverage) && Coverage.respond_to?(:peek_result)
  CovetCoverage = Coverage
else
  # TODO: error out if non-mri ruby
  begin
    require_relative 'covet_coverage'
  rescue Exception # re-raised
    $stderr.puts "Error loading 'covet' C extension.\n" \
      "Please report this bug along with a backtrace. Thanks :)"
    raise
  end
end
require_relative 'covet/collection_filter'
require_relative 'covet/collection_compressor'
require_relative 'covet/vcs'
require_relative 'covet/log_collection'
require_relative 'covet/cli'

# just for testing purposes
if ENV['COVET_DEBUG']
  if RUBY_VERSION < '2.0'
    gem 'debugger'
    require 'debugger'
  else
    gem 'byebug'
    require 'byebug'
  end
#else
  #if !defined?(debugger)
    #def debugger; end
  #end
end

module Covet
  BASE_COVERAGE = {}

  # @return Hash
  def self.options
    CLI.options || Options::DEFAULTS
  end

  # Singleton for collecting and writing log information during the collection phase.
  def self.log_collection
    @log_collection
  end

  # TODO: filename should depend on covet options and there should
  # be multiple run logs in a .covet_run_logs directory or something
  @log_collection = LogCollection.new(
    :filename => File.join(Dir.pwd, 'run_log.json'),
    :bufsize => 50,
  )

  # Set the version control system to use for seeing which files have changed
  # since a certain version.
  def self.vcs=(vcs)
    @vcs = vcs.intern
    if @vcs != :git
      raise NotImplementedError, "Can only use git as the VCS for now."
    end
  end
  def self.vcs; @vcs; end

  self.vcs = :git # default

  # Set the test runner library to hook into, gathering and logging coverage
  # information during the collection phase for each test method.
  def self.test_runner=(runner)
    @test_runner = runner.intern
    require_relative "covet/test_runners/#{runner}"
  rescue LoadError
    raise ArgumentError, "invalid test runner given: '#{runner}'. " \
      "Expected 'rspec' or 'minitest'"
  end
  def self.test_runner; @test_runner; end

  if (runner = ENV['COVET_TEST_RUNNER'])
    self.test_runner = runner
  else
    self.test_runner = :minitest # default
  end

  # Tell `covet` the order in which your tests are run, which allows it to
  # save space and time during the coverage collection phase in certain situations.
  VALID_TEST_ORDERS = [:random_seeded, :random, :ordered].freeze
  def self.test_order=(order)
    unless VALID_TEST_ORDERS.include?(order.intern)
      raise ArgumentError, "Invalid test order given. Expected one of " \
        "#{VALID_TEST_ORDERS.map(&:inspect).join(", ")} - #{order.intern.inspect} given"
    end
    @test_order = order
  end
  def self.test_order; @test_order; end

  self.test_order = :random_seeded # default

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

  # FIXME: make this configurable, the test directory could be something else
  self.test_directories = []
  if Dir.exist?('test')
    self.test_directories = self.test_directories + ['test']
  end
  if Dir.exist?('spec')
    self.test_directories = self.test_directories + ['spec']
  end

  @coverage_collection_registered = false
  # Register coverage collection with the test library `Covet.test_runner`.
  # This happens during the collection phase.
  def self.register_coverage_collection!
    # stdlib Coverage can't run at the same time as CovetCoverage or
    # bad things will happen
    if defined?(Coverage) && !Coverage.respond_to?(:peek_result)
      warn "The 'coverage' library is already loaded. It could cause issues with this library."
      # There's no way to tell if coverage is enabled or not, and
      # if we try stopping the coverage and it's not enabled, it raises
      # a RuntimeError.
      Coverage.stop rescue nil
    end
    CovetCoverage.start # needs to be called before any application code gets required
    Covet::TestRunners.const_get(
      @test_runner.to_s.capitalize
    ).hook_into_test_methods!
    @coverage_collection_registered = true
  end

  def self.coverage_collection_registered?
    @coverage_collection_registered
  end

  # Returns the command line to run the tests given in `run_list`.
  # @return String
  def self.cmdline_for_run_list(run_list, options = {})
    Covet::TestRunners.const_get(
      @test_runner.to_s.capitalize
    ).cmdline_for_run_list(run_list, options)
  end

  # Returns coverage information for before block ran, and after block ran
  # for the codebase in its current state.
  # @return Array
  def self.coverage_before_and_after # yields
    before = CovetCoverage.peek_result
    yield
    after = CovetCoverage.peek_result
    before = normalize_coverage_info(before)
    if Covet::BASE_COVERAGE.any?
      before = diff_coverages(Covet::BASE_COVERAGE, before)
    end
    after = normalize_coverage_info(after)
    after = diff_coverages(before, after)
    [before, after]
  end

  # Filter and compress `coverage_info` to make it more manageable to log
  # to the collection file, and so that processing it will be faster.
  def self.normalize_coverage_info(coverage_info)
    filtered = CollectionFilter.filter(coverage_info)
    CollectionCompressor.compress(filtered)
  end

  # Generates a mapping of filenames to the lines and test methods that
  # caused the changes.
  # @return Hash, example:
  #   { "/home/me/workspace/myproj/myproj.rb" => { 1 => ['test_method_that_caused_changed']} }
  def self.generate_run_list_for_method(before, after, options = {})
    cov_map = Hash.new { |h, file| h[file] = Hash.new { |i, line| i[line] = [] } }
    after.each do |file, lines_hash|
      file_map = cov_map[file]

      lines_hash.each do |lineno, exec_times|
        # add the test name to the map. Multiple tests can execute the same
        # line, so we need to use an array.
        file_map[lineno] << (options[:method_name] || '???').to_s
      end
    end
    cov_map
  end

  # Get the difference between `before`'s coverage info and `after`'s coverage
  # info.
  # @param [Hash] before
  # @param [Hash] after
  # @return Hash
  def self.diff_coverages(before, after)
    ret = after.each_with_object({}) do |(file_name, after_line_cov), res|
      before_line_cov = before[file_name] || {}
      next if before_line_cov == after_line_cov

      cov = {}

      after_line_cov.each do |lineno, exec_times|
        # no change
        if (before_exec_times = before_line_cov[lineno]) == exec_times
          next
        end

        # execution of previous line number
        if before_exec_times && exec_times
          cov[lineno] = exec_times - before_exec_times
        elsif exec_times
          cov[lineno] = exec_times
        else
          raise "shouldn't get here"
        end
      end

      # add the "diffed" coverage to the hash
      res[file_name] = cov
    end
    ret
  end
end

if ENV['COVET_COLLECT'] == '1' && !Covet.coverage_collection_registered?
  Covet.register_coverage_collection!
end
