require_relative 'spec_helper'

first_logs = []
RSpec.describe do "Each spec method"
  it "1. should be wrapped in coverage collection" do
    first_logs = Covet::COLLECTION_LOGS.dup
  end

  it "2. should be wrapped in coverage collection" do
    Covet::COLLECTION_LOGS.size.should_not equal(first_logs.size)
  end
end
