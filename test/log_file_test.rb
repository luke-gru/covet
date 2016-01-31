require_relative 'test_helper'
require 'tempfile'

class LogFileTest < CovetUnitTest
  @@tempfile = Tempfile.new('test')
  @@tempfile.close

  def test_write_buf_uses_index_file
    index_fname = @@tempfile.path + 'index'
    logfile = Covet::LogFile.new(
      :filename => @@tempfile.path,
      :index_filename => index_fname
    )
    logfile.write_start
    100.times do |i|
      buf = Array.new(100, i)
      logfile.write_buf(buf)
    end
    logfile.write_end
    assert_equal 102, logfile.writes
    ary = logfile.load!
    assert_equal 100, ary.size
    assert_equal 100, ary[0].size
    assert_equal 0, ary[0][0]
    assert_kind_of Array, ary
  end

  def test_each_buf_using_index_file
    index_fname = @@tempfile.path + 'index'
    logfile = Covet::LogFile.new(
      :filename => @@tempfile.path,
      :index_filename => index_fname
    )

    logfile.write_start
    100.times do |i|
      buf = Array.new(100, i)
      logfile.write_buf(buf)
    end
    logfile.write_end

    all_bufs = []
    logfile.load_each_buf! do |buf|
      all_bufs << buf
    end
    assert_equal 100, all_bufs.size
    assert all_bufs.all? { |buf| buf.size == 100 }
  end

end
