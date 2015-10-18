require_relative 'test_helper'

class RunListTest < CovetTest
  def test_empty_run_list_for_method
    before, after = coverage_before_and_after { }
    list = generate_run_list_for_method(before, after, :method_name => __method__)
    assert_equal Hash, list.class
    methods_to_run = list.values.map(&:values).flatten.uniq
    assert list.empty? || methods_to_run == [__method__.to_s]
  end

  def test_non_empty_run_list_for_method_due_to_changed_lib_file
    obj = MyClass.new
    assert_equal :hi, obj.hello?
    fname = File.expand_path('../fakelib.rb', __FILE__)

    before, after = coverage_before_and_after do
      change_file(fname, 8, "def goodbye; 'bye'; end") do
        load fname
      end
      obj = MyClass.new
      assert_equal 'bye', obj.goodbye
    end

    refute_equal before, after
    list = generate_run_list_for_method(before, after, :method_name => __method__)
    assert_equal Hash, list.class
    assert !list.empty?
    assert list[fname]
  end
end
