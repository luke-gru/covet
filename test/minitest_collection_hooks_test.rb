require_relative 'test_helper'

class MinitestCollectionHooks < CovetTest
  @@first_logs = []

  def self.test_order
    :sorted
  end

  def test_1
    @@first_logs = Covet::COLLECTION_LOGS.dup
    # do nothing, assertion(s) are in next test
  end

  def test_2
    assert Covet::COLLECTION_LOGS.any?
    assert Covet::COLLECTION_LOGS.size != @@first_logs.size
  end
end
