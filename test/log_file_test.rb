require_relative 'test_helper'
require 'tempfile'

class LogFileTest < CovetUnitTest
  def setup
    super
    tempfile = Tempfile.new('test')
    @index_fname = tempfile.path + 'index'
    @logfile = Covet::LogFile.new(
      :filename => tempfile.path,
      :index_filename => @index_fname
    )
  end

  def test_write_buf_uses_index_file
    @logfile.write_start
    100.times do |i|
      buf = Array.new(100, i)
      @logfile.write_buf(buf)
    end
    refute File.exist?(@index_fname)
    @logfile.write_end
    assert File.exist?(@index_fname)
    assert_equal 102, @logfile.writes
    ary = @logfile.load!
    assert_equal 100, ary.size
    assert_equal 100, ary[0].size
    assert_equal 0, ary[0][0]
    assert_kind_of Array, ary
  end

  def test_load_each_buf_using_index_file
    @logfile.write_start
    100.times do |i|
      buf = Array.new(100, i)
      @logfile.write_buf(buf)
    end
    @logfile.write_end
    all_bufs = []
    @logfile.load_each_buf! do |buf|
      all_bufs << buf
    end
    assert_equal 100, all_bufs.size
    assert all_bufs.all? { |buf| buf.size == 100 }
  end

  def test_corrupted_log_file_raises_proper_error_when_using_load
    @logfile.write_start
    10.times do |i|
      buf = Array.new(10, i)
      @logfile.write_buf(buf)
    end
    @logfile.write_end
    File.open(@logfile.name, 'a') { |f| f.write(']]]') }  # corrupt the file
    assert_raises Covet::LogFile::LoadError do
      @logfile.load!
    end
  end

  def test_corrupted_log_file_raises_proper_error_when_using_load_each_buf
    @logfile.write_start
    10.times do |i|
      buf = Array.new(10, i)
      @logfile.write_buf(buf)
    end
    @logfile.write_end
    File.open(@logfile.name, 'w') { |f| f.write('}xo') }  # corrupt the file
    assert_raises Covet::LogFile::LoadError do
      @logfile.load_each_buf! { |_buf| }
    end
  end

  def test_corrupted_log_file_index_raises_proper_error_when_using_load_each_buf
    @logfile.write_start
    10.times do |i|
      buf = Array.new(10, i)
      @logfile.write_buf(buf)
    end
    @logfile.write_end
    File.open(@logfile.index_file.name, 'w') { |f| f.write('}xo') }  # corrupt the file
    assert_raises Covet::LogFile::LoadIndexError do
      @logfile.load_each_buf! { |buf| buf }
    end
  end

  def test_load_each_buf_without_block_returns_enum
    @logfile.write_start
    10.times do |i|
      buf = Array.new(100, i)
      @logfile.write_buf(buf)
    end
    @logfile.write_end
    enum = @logfile.load_each_buf!
    assert_kind_of Enumerator, enum
    first_buf = enum.first
    assert_equal 100, first_buf.size
  end

end
