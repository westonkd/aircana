# frozen_string_literal: true

RSpec.describe Aircana do
  it "has a version number" do
    expect(Aircana::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(Aircana).to respond_to(:configuration)
    expect(Aircana).to respond_to(:logger)
  end
end
