require_relative '../test_helper'

class RemoveFileTest < CovetIntegrationTest
  def test_removing_library_file_causes_entire_test_suite_to_run
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      remove_file!('main.rb')
      out, _err = template_run("bundle exec covet")
      assert_match /You need to run every test file/, out
    end
  end
end
