# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::Contexts::Local do
  let(:local) { described_class.new }

  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory
      original_config = Aircana.configuration.agent_knowledge_dir
      Aircana.configuration.agent_knowledge_dir = File.join(temp_dir, ".aircana", "agents")

      example.run

      # Restore original configuration
      Aircana.configuration.agent_knowledge_dir = original_config
    end
  end

  describe "#store_content" do
    it "creates agent directory and stores content as markdown" do
      result = local.store_content(
        title: "Test Page",
        content: "# Test Content\n\nThis is a test.",
        agent: "test-agent"
      )

      expected_dir = File.join(Aircana.configuration.agent_knowledge_dir, "test-agent", "knowledge")
      expected_file = File.join(expected_dir, "Test-Page.md")

      expect(Dir.exist?(expected_dir)).to be true
      expect(File.exist?(expected_file)).to be true
      expect(File.read(expected_file)).to eq("# Test Content\n\nThis is a test.")
      expect(result).to eq(expected_file)
    end

    it "sanitizes problematic characters in filenames" do
      result = local.store_content(
        title: "Test/Page: With\"Problematic*Characters<>|?",
        content: "Content",
        agent: "test-agent"
      )

      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        "Test-Page-With-Problematic-Characters.md"
      )

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "handles empty titles" do
      result = local.store_content(
        title: "",
        content: "Content",
        agent: "test-agent"
      )

      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        "untitled.md"
      )

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "handles titles with only spaces" do
      result = local.store_content(
        title: "   ",
        content: "Content",
        agent: "test-agent"
      )

      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        "untitled.md"
      )

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "replaces multiple spaces with single hyphens" do
      result = local.store_content(
        title: "Test   Page    With     Spaces",
        content: "Content",
        agent: "test-agent"
      )

      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        "Test-Page-With-Spaces.md"
      )

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "truncates very long titles" do
      long_title = "a" * 250
      result = local.store_content(
        title: long_title,
        content: "Content",
        agent: "test-agent"
      )

      expected_filename = "#{"a" * 200}.md"
      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        expected_filename
      )

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "stores content for different agents in separate directories" do
      local.store_content(title: "Page 1", content: "Content 1", agent: "agent-1")
      local.store_content(title: "Page 2", content: "Content 2", agent: "agent-2")

      agent1_file = File.join(Aircana.configuration.agent_knowledge_dir, "agent-1", "knowledge", "Page-1.md")
      agent2_file = File.join(Aircana.configuration.agent_knowledge_dir, "agent-2", "knowledge", "Page-2.md")

      expect(File.exist?(agent1_file)).to be true
      expect(File.exist?(agent2_file)).to be true
      expect(File.read(agent1_file)).to eq("Content 1")
      expect(File.read(agent2_file)).to eq("Content 2")
    end

    it "overwrites existing files with the same title" do
      # Store initial content
      local.store_content(title: "Test Page", content: "Original content", agent: "test-agent")

      # Store updated content with same title
      result = local.store_content(title: "Test Page", content: "Updated content", agent: "test-agent")

      expected_file = File.join(
        Aircana.configuration.agent_knowledge_dir,
        "test-agent",
        "knowledge",
        "Test-Page.md"
      )

      expect(File.read(expected_file)).to eq("Updated content")
      expect(result).to eq(expected_file)
    end
  end
end
