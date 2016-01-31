require_relative 'test_helper'
require 'tempfile'

class LogCollectionTest < CovetUnitTest
  @@tempfile = Tempfile.new('test')
  @@tempfile.close

  def setup
    @logs = Covet::LogCollection.new(
      :filename => @@tempfile.path,
      :bufsize => 20
    )
  end

  def test_append_and_finish
    100.times do |i|
      @logs << [i]
    end
    assert_equal 5, @logs.flushes
    @logs << [42]
    assert @logs.finish!
    assert_equal 6, @logs.flushes
    assert !File.read(@@tempfile.path).empty?
  end

end
