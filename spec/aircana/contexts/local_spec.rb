# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::Contexts::Local do
  let(:local) { described_class.new }

  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory for KB knowledge
      original_kb_dir = Aircana.configuration.kb_knowledge_dir
      original_plugin_root = Aircana.configuration.plugin_root

      Aircana.configuration.kb_knowledge_dir = File.join(temp_dir, ".claude", "skills")
      Aircana.configuration.plugin_root = temp_dir

      example.run

      # Restore original configuration
      Aircana.configuration.kb_knowledge_dir = original_kb_dir
      Aircana.configuration.plugin_root = original_plugin_root
    end
  end

  describe "#store_content" do
    it "creates KB directory and stores content as markdown" do
      result = local.store_content(
        title: "Test Page",
        content: "# Test Content\n\nThis is a test.",
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
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
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_file = File.join(expected_dir, "Test-Page-With-Problematic-Characters.md")

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "handles empty titles" do
      result = local.store_content(
        title: "",
        content: "Content",
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_file = File.join(expected_dir, "untitled.md")

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "handles titles with only spaces" do
      result = local.store_content(
        title: "   ",
        content: "Content",
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_file = File.join(expected_dir, "untitled.md")

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "replaces multiple spaces with single hyphens" do
      result = local.store_content(
        title: "Test   Page    With     Spaces",
        content: "Content",
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_file = File.join(expected_dir, "Test-Page-With-Spaces.md")

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "truncates very long titles" do
      long_title = "a" * 250
      result = local.store_content(
        title: long_title,
        content: "Content",
        kb_name: "test-kb"
      )

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_filename = "#{"a" * 200}.md"
      expected_file = File.join(expected_dir, expected_filename)

      expect(File.exist?(expected_file)).to be true
      expect(result).to eq(expected_file)
    end

    it "stores content for different KBs in separate directories" do
      local.store_content(title: "Page 1", content: "Content 1", kb_name: "kb-1")
      local.store_content(title: "Page 2", content: "Content 2", kb_name: "kb-2")

      kb1_dir = Aircana.configuration.kb_knowledge_path("kb-1")
      kb2_dir = Aircana.configuration.kb_knowledge_path("kb-2")
      kb1_file = File.join(kb1_dir, "Page-1.md")
      kb2_file = File.join(kb2_dir, "Page-2.md")

      expect(File.exist?(kb1_file)).to be true
      expect(File.exist?(kb2_file)).to be true
      expect(File.read(kb1_file)).to eq("Content 1")
      expect(File.read(kb2_file)).to eq("Content 2")
    end

    it "overwrites existing files with the same title" do
      # Store initial content
      local.store_content(title: "Test Page", content: "Original content", kb_name: "test-kb")

      # Store updated content with same title
      result = local.store_content(title: "Test Page", content: "Updated content", kb_name: "test-kb")

      expected_dir = Aircana.configuration.kb_knowledge_path("test-kb")
      expected_file = File.join(expected_dir, "Test-Page.md")

      expect(File.read(expected_file)).to eq("Updated content")
      expect(result).to eq(expected_file)
    end
  end
end
