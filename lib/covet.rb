require_relative 'coverage/peek_result'

module Covet
  def self.vcs=(vcs)
    @vcs = vcs
  end
  self.vcs = :git # default

end

require 'json'
require 'minitest'
CovetCoverage.start

class Minitest::Runnable
  LOGS = []

  Minitest.after_run {
    File.open('run_log.json', 'w') { |f| f.write JSON.dump LOGS }
  }

  class << self
    alias :old_run_one_method :run_one_method

    def run_one_method klass, method_name, reporter
      before = CovetCoverage.peek_result
      old_run_one_method klass, method_name, reporter
      after = CovetCoverage.peek_result
      LOGS << [ klass.name, method_name.to_s, before, after ]
    end
  end
end

module Covet
end
