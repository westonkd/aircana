# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::Checksum do
  describe ".compute" do
    it "returns sha256-prefixed hash for valid content" do
      result = described_class.compute("test content")

      expect(result).to start_with("sha256:")
      expect(result.length).to eq(71)
    end

    it "returns consistent hash for same content" do
      content = "some test content"

      result1 = described_class.compute(content)
      result2 = described_class.compute(content)

      expect(result1).to eq(result2)
    end

    it "returns different hashes for different content" do
      result1 = described_class.compute("content one")
      result2 = described_class.compute("content two")

      expect(result1).not_to eq(result2)
    end

    it "returns nil for nil content" do
      result = described_class.compute(nil)

      expect(result).to be_nil
    end

    it "returns nil for empty content" do
      result = described_class.compute("")

      expect(result).to be_nil
    end
  end

  describe ".match?" do
    let(:content) { "test content" }
    let(:checksum) { described_class.compute(content) }

    it "returns true for matching content" do
      result = described_class.match?(checksum, content)

      expect(result).to be true
    end

    it "returns false for different content" do
      result = described_class.match?(checksum, "different content")

      expect(result).to be false
    end

    it "returns false when stored checksum is nil" do
      result = described_class.match?(nil, content)

      expect(result).to be false
    end

    it "returns false when content is nil" do
      result = described_class.match?(checksum, nil)

      expect(result).to be false
    end

    it "returns false when both are nil" do
      result = described_class.match?(nil, nil)

      expect(result).to be false
    end
  end
end
