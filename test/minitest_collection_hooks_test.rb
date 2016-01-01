require_relative 'test_helper'

class MinitestCollectionHooks < CovetTest
  @@first_logs = []

  def self.test_order
    :sorted
  end

  def test_1_collect_for_next_test
    @@first_logs = Covet.log_collection.instance_variable_get("@buf").dup
    # do nothing, assertion(s) are in next test
  end

  def test_2_log_collection_size_increases_after_test
    assert Covet.log_collection.size > 0
    assert Covet.log_collection.size != @@first_logs.size
  end
end
