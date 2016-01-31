gem 'minitest'
begin
  require 'minitest' # minitest 5
  Minitest.autorun
rescue LoadError
  require 'minitest/unit' # minitest 4
  require 'minitest/autorun'
end

require 'covet'
require_relative '../main' # This file must exist
STDERR.puts RUBY_VERSION

class RepoTest < defined?(Minitest::Test) ? Minitest::Test : Minitest::Unit::TestCase
end
