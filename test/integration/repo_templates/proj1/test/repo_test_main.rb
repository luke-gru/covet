require_relative 'test_helper'

class MainTest < RepoTest
  def setup
    @main = Main.new(initial: 0)
  end

  def test_calc_add
    assert_equal 0, @main.result
    assert_equal 2, @main.add(2)
    assert_equal 2, @main.result
  end

end
