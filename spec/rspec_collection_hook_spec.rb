require_relative 'spec_helper'

first_logs_size = 0
RSpec.describe do "Each spec method"
  it "1. should be wrapped in coverage collection" do
    first_logs_size = Covet.log_collection.size
  end

  it "2. should be wrapped in coverage collection" do
    Covet.log_collection.size.should_not equal(first_logs_size)
  end
end
