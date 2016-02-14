require_relative '../test_helper'

class RenameFileTest < CovetIntegrationTest
  def test_renaming_library_file_causes_entire_test_suite_to_run
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      rename_file!('main.rb', 'main2.rb')
      out, _err = template_run("bundle exec covet")
      assert_match /You need to run every test file/, out
    end
  end
end
