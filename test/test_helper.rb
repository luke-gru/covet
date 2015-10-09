require_relative '../lib/covet'
require_relative 'fakelib'
gem 'minitest'
require 'minitest/autorun'

Covet.register_coverage_collection!

class CovetTest < MiniTest::Test

  def diff_coverage_for(&block)
    Covet.diff_coverage_for(&block)
  end

  def generate_run_list_for_method(before, after, options = {})
    Covet.generate_run_list_for_method(before, after, options)
  end

  def change_file(fname, lineno, new_line) # yields
    check_file_exists!(fname)
    new_line << "\n" unless new_line.end_with?("\n")
    contents = File.read(fname).lines.to_a
    old_contents = contents.dup
    old_line = contents[lineno - 1]
    if old_line.nil?
      raise ArgumentError, "invalid line number for #{fname}: #{lineno}"
    end
    contents[lineno - 1] = new_line
    File.open(fname, 'w') {|f| f.write contents.join }
    yield
  ensure
    if old_contents
      File.open(fname, 'w') {|f| f.write old_contents.join }
    end
  end

  def remove_file(fname) # yields
    check_file_exists!(fname)
    # TODO
  end

  def rename_file(fname, new_name) # yields
    check_file_exists!(fname)
    # TODO
  end

  def add_file(fname, contents) # yields
    check_file_doesnt_exist!(fname)
    # TODO
  end

  def with_collection_filter(filter) # yields
    # TODO
  end

  private

    def check_file_exists!(fname)
      unless File.exist?(fname)
        raise ArgumentError, "file doesn't exist: #{fname}"
      end
    end

    def check_file_doesnt_exist!(fname)
      if File.exist?(fname)
        raise ArgumentError, "file already exists: #{fname}"
      end
    end

end
