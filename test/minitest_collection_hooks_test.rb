require_relative 'test_helper'

class MinitestCollectionHooks < CovetTest
  @@first_logs = []

  def self.test_order
    :sorted
  end

  def test_1
    @@first_logs = Covet.log_collection.instance_variable_get("@buf").dup
    # do nothing, assertion(s) are in next test
  end

  def test_2
    assert Covet.log_collection.size > 0
    assert Covet.log_collection.size != @@first_logs.size
  end
end
