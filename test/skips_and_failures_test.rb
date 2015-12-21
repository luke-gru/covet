require_relative 'test_helper'

class SkipsAndFailuresTest < CovetTest
  def self.test_order
    :sorted
  end

  @@collections = nil

  def setup
    # ... do nothing. Don't call super to make sure coverage information isn't cleared before each new test
  end

  def test_1_skip
    @@collections = Covet.log_collection.instance_variable_get("@buf").dup
    skip 'for next test'
  end

  def test_2_skips_dont_update_coverage_collection
    assert_equal @@collections, Covet.log_collection.instance_variable_get("@buf")
  end

end
