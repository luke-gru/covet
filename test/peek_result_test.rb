require 'tmpdir'

class PeekResultTest < MiniTest::Test
  # Aaron's original test for `Coverage::peek_result` in
  # https://github.com/ruby/ruby/commit/a86eacf552c0f3a7862d6891cf174007d96f656a
  def test_coverage_snapshot
    loaded_features = $".dup

    Dir.mktmpdir {|tmp|
      Dir.chdir(tmp) {
        File.open("test.rb", "w") do |f|
          f.puts <<-EOS
            def coverage_test_method
              :ok
            end
          EOS
        end
        require tmp + '/test.rb'
        cov = CovetCoverage.peek_result[tmp + '/test.rb']
        coverage_test_method
        cov2 = CovetCoverage.peek_result[tmp + '/test.rb']
        assert_equal cov[1] + 1, cov2[1]
        assert_equal cov2, CovetCoverage.result[tmp + '/test.rb']
      }
    }
  ensure
    $".replace loaded_features
  end
end
