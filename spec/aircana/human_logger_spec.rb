# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::HumanLogger do
  let(:output) { StringIO.new }
  let(:logger) { described_class.new(output) }

  describe "#success" do
    it "logs success messages with green color and checkmark" do
      logger.success("Operation completed")

      expect(output.string).to include("✅")
      expect(output.string).to include("Operation completed")
      expect(output.string).to include("\e[32m") # Green color
    end
  end

  describe "#error" do
    it "logs error messages with red color and X mark" do
      logger.error("Something went wrong")

      expect(output.string).to include("❌")
      expect(output.string).to include("Something went wrong")
      expect(output.string).to include("\e[31m") # Red color
    end
  end

  describe "#warn" do
    it "logs warning messages with yellow color and warning sign" do
      logger.warn("This is a warning")

      expect(output.string).to include("⚠️")
      expect(output.string).to include("This is a warning")
      expect(output.string).to include("\e[33m") # Yellow color
    end
  end

  describe "#info" do
    it "logs info messages with cyan color and info sign" do
      logger.info("General information")

      expect(output.string).to include("ℹ️")
      expect(output.string).to include("General information")
      expect(output.string).to include("\e[36m") # Cyan color
    end
  end

  describe "context-aware emoji selection" do
    it "uses agent emoji for agent-related messages" do
      logger.info("Agent created successfully")
      expect(output.string).to include("🤖")
    end

    it "uses file emoji for file-related messages" do
      logger.info("File created at /path/to/file")
      expect(output.string).to include("📁")
    end

    it "uses pages emoji for page count messages" do
      logger.info("Found 5 pages for processing")
      expect(output.string).to include("📄")
    end

    it "uses created emoji for creation messages" do
      logger.info("Generated new configuration")
      expect(output.string).to include("📝")
    end

    it "uses stored emoji for storage messages" do
      logger.info("Stored content successfully")
      expect(output.string).to include("💾")
    end

    it "uses network emoji for network-related messages" do
      logger.info("HTTP request completed")
      expect(output.string).to include("🌐")
    end

    it "uses found emoji for search results" do
      logger.info("Found 10 matching items")
      expect(output.string).to include("🔍")
    end
  end

  describe "priority handling" do
    it "prioritizes context-based emojis over action-based ones" do
      logger.info("Created agent configuration file")
      expect(output.string).to include("🤖") # Agent emoji should take precedence over created
    end
  end
end
