require 'rake/tasklib'

module Covet
  # Define a new rake task to collect coverage information for a `TestTask`.
  # Usage (in Rakefile):
  #
  #   require 'rake/testtask'
  #   require 'covet/collection_task'
  #
  #   Rake::TestTask.new(:my_tests) do |t|
  #     t.verbose = true
  #   end
  #
  #   Covet::CollectionTask.new(:collect) do |t|
  #     t.test_task = :my_tests
  #     t.description = "Collect coverage information for my_tests"
  #   end
  #
  # Now, we can can run '$ rake collect'.
  class CollectionTask < Rake::TaskLib

    attr_accessor :name
    attr_accessor :description
    attr_accessor :test_task # Rake::TestTask or Symbol
    attr_accessor :covet_opts # Array of cmdline covet options

    def initialize(name = :covet_collect) # yields
      @name = name
      @description = nil
      @test_task = nil
      @covet_opts = []
      yield self if block_given?
      define
    end

    # Define the task
    def define
      if @test_task.nil?
        raise "#{self.class} '#{@name}' is not properly set up. " \
          "This task needs a `test_task` that's either the `Rake::TestTask` " \
          "object to test or the name of that `TestTask` object. You can assign " \
          "it using the `test_task=` method on the instance of #{self.class}."
      end
      @description ||= "Collect coverage information for task '#{test_task_name}'"
      desc @description
      task @name do
        cmd = %Q(covet -c "rake #{test_task_name}" #{@covet_opts.join(' ')}).strip
        puts cmd
        system cmd
      end
    end

    private

      def test_task_name
        @test_task.respond_to?(:name) ? @test_task.name : @test_task
      end

  end
end
