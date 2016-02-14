require_relative '../test_helper'

class ChangeCodeThatRunsOnLoadTest < CovetIntegrationTest
  def test_change_to_code_that_runs_on_app_load_makes_you_run_entire_suite_again
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      change_file!('main.rb', 1 => 'class Spain')
      out, _err = template_run("bundle exec covet")
      assert_match /You need to run every test file/, out
    end
  end

  def test_no_change_to_code_doesnt_makes_you_run_entire_suite_again
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      out, _err = template_run("bundle exec covet")
      refute_match /You need to run every test file/, out
    end
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      change_file!('main.rb', 1 => 'class Main')
      out, _err = template_run("bundle exec covet")
      refute_match /You need to run every test file/, out
    end
  end

  def test_change_to_code_that_doesnt_run_on_app_load_doesnt_makes_you_run_entire_suite_again
    with_new_repo(template: 'proj1') do |repo|
      run_covet_collect!
      change_file!('main.rb', 4 => '@result = 0')
      out, _err = template_run("bundle exec covet")
      refute_match /You need to run every test file/, out
    end
  end

end
