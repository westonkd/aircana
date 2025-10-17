# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::Generators::SkillsGenerator do
  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory
      original_skills_dir = Aircana.configuration.skills_dir
      Aircana.configuration.skills_dir = File.join(temp_dir, ".claude", "skills")

      example.run

      # Restore original configuration
      Aircana.configuration.skills_dir = original_skills_dir
    end
  end

  describe "#initialize" do
    it "creates generator with required parameters" do
      generator = described_class.new(
        kb_name: "test-kb",
        skill_description: "Test description",
        knowledge_files: []
      )

      expect(generator.kb_name).to eq("test-kb")
      expect(generator.skill_description).to eq("Test description")
      expect(generator.knowledge_files).to eq([])
    end

    it "generates default skill description from kb_name" do
      generator = described_class.new(kb_name: "my-test-kb")

      expect(generator.skill_description).to eq("Discover critical context for my test kb")
    end

    it "uses short_description to generate skill description" do
      generator = described_class.new(
        kb_name: "test-kb",
        short_description: "Docker configuration"
      )

      expect(generator.skill_description).to eq("Discover critical context for Docker configuration")
    end
  end

  describe ".from_manifest" do
    let(:kb_name) { "test-kb" }
    let(:manifest) do
      {
        "version" => "1.0",
        "name" => kb_name,
        "kb_type" => "local",
        "sources" => [
          {
            "type" => "confluence",
            "pages" => [
              { "id" => "123456", "summary" => "API documentation for REST endpoints" },
              { "id" => "789012", "summary" => "Authentication and authorization guide" }
            ]
          },
          {
            "type" => "web",
            "urls" => [
              { "url" => "https://example.com/user-guide", "summary" => "User guide for administrators" }
            ]
          }
        ]
      }
    end

    before do
      allow(Aircana::Contexts::Manifest).to receive(:read_manifest)
        .with(kb_name).and_return(manifest)
    end

    it "creates generator from manifest data" do
      generator = described_class.from_manifest(kb_name)

      expect(generator.kb_name).to eq(kb_name)
      expect(generator.skill_description).to eq("Discover critical context for test kb from 2 knowledge sources")
      expect(generator.knowledge_files.size).to eq(3)
    end

    it "extracts knowledge files with summaries" do
      generator = described_class.from_manifest(kb_name)

      expect(generator.knowledge_files).to contain_exactly(
        { summary: "API documentation for REST endpoints", filename: "page_123456.md" },
        { summary: "Authentication and authorization guide", filename: "page_789012.md" },
        { summary: "User guide for administrators", filename: "user-guide.md" }
      )
    end

    it "raises error when manifest doesn't exist" do
      allow(Aircana::Contexts::Manifest).to receive(:read_manifest)
        .with("nonexistent-kb").and_return(nil)

      expect do
        described_class.from_manifest("nonexistent-kb")
      end.to raise_error(Aircana::Error, "No manifest found for knowledge base 'nonexistent-kb'")
    end
  end

  describe ".extract_knowledge_files_from_manifest" do
    it "extracts Confluence page files with summaries" do
      manifest = {
        "sources" => [
          {
            "type" => "confluence",
            "pages" => [
              { "id" => "123", "summary" => "Test page summary" },
              { "id" => "456", "summary" => "Another page summary" }
            ]
          }
        ]
      }

      files = described_class.extract_knowledge_files_from_manifest(manifest)

      expect(files).to eq([
                            { summary: "Test page summary", filename: "page_123.md" },
                            { summary: "Another page summary", filename: "page_456.md" }
                          ])
    end

    it "extracts web URL files with summaries" do
      manifest = {
        "sources" => [
          {
            "type" => "web",
            "urls" => [
              { "url" => "https://example.com/guide", "summary" => "User guide" },
              { "url" => "https://docs.example.com/api", "summary" => "API reference" }
            ]
          }
        ]
      }

      files = described_class.extract_knowledge_files_from_manifest(manifest)

      expect(files).to eq([
                            { summary: "User guide", filename: "guide.md" },
                            { summary: "API reference", filename: "api.md" }
                          ])
    end

    it "handles manifest with multiple source types" do
      manifest = {
        "sources" => [
          {
            "type" => "confluence",
            "pages" => [{ "id" => "123", "summary" => "Confluence page" }]
          },
          {
            "type" => "web",
            "urls" => [{ "url" => "https://example.com/guide", "summary" => "Web guide" }]
          }
        ]
      }

      files = described_class.extract_knowledge_files_from_manifest(manifest)

      expect(files.size).to eq(2)
      expect(files[0][:filename]).to eq("page_123.md")
      expect(files[1][:filename]).to eq("guide.md")
    end

    it "handles empty manifest" do
      manifest = { "sources" => [] }

      files = described_class.extract_knowledge_files_from_manifest(manifest)

      expect(files).to eq([])
    end

    it "provides fallback summaries when missing" do
      manifest = {
        "sources" => [
          {
            "type" => "confluence",
            "pages" => [{ "id" => "123" }]
          },
          {
            "type" => "web",
            "urls" => [{ "url" => "https://example.com" }]
          }
        ]
      }

      files = described_class.extract_knowledge_files_from_manifest(manifest)

      expect(files[0][:summary]).to eq("Documentation")
      expect(files[1][:summary]).to eq("Web resource")
    end
  end

  describe ".generate_skill_description_from_manifest" do
    it "generates description with source count" do
      manifest = {
        "sources" => [
          { "type" => "confluence" },
          { "type" => "web" }
        ]
      }

      description = described_class.generate_skill_description_from_manifest(manifest, "my-test-kb")

      expect(description).to eq("Discover critical context for my test kb from 2 knowledge sources")
    end

    it "handles manifest with no sources" do
      manifest = { "sources" => [] }

      description = described_class.generate_skill_description_from_manifest(manifest, "empty-kb")

      expect(description).to eq("Discover critical context for empty kb from 0 knowledge sources")
    end

    it "formats kb name with spaces" do
      manifest = { "sources" => [{ "type" => "confluence" }] }

      description = described_class.generate_skill_description_from_manifest(manifest, "docker-production-guide")

      expect(description).to eq("Discover critical context for docker production guide from 1 knowledge sources")
    end
  end

  describe ".sanitize_filename_from_id" do
    it "creates filename from page ID" do
      filename = described_class.sanitize_filename_from_id("123456")
      expect(filename).to eq("page_123456")
    end
  end

  describe ".sanitize_filename_from_url" do
    it "extracts filename from URL path" do
      filename = described_class.sanitize_filename_from_url("https://example.com/user-guide")
      expect(filename).to eq("user-guide")
    end

    it "extracts filename from multi-segment path" do
      filename = described_class.sanitize_filename_from_url("https://example.com/docs/api/reference")
      expect(filename).to eq("reference")
    end

    it "uses host when no path exists" do
      filename = described_class.sanitize_filename_from_url("https://example.com")
      expect(filename).to eq("example-com")
    end

    it "sanitizes special characters" do
      filename = described_class.sanitize_filename_from_url("https://example.com/guide@v2.0")
      expect(filename).to eq("guide-v2-0")
    end

    it "handles invalid URIs" do
      filename = described_class.sanitize_filename_from_url("not a valid url")
      expect(filename).to eq("web_resource")
    end

    it "lowercases the filename" do
      filename = described_class.sanitize_filename_from_url("https://example.com/USER-GUIDE")
      expect(filename).to eq("user-guide")
    end

    it "removes consecutive hyphens" do
      filename = described_class.sanitize_filename_from_url("https://example.com/user---guide")
      expect(filename).to eq("user-guide")
    end
  end

  describe "#generate" do
    it "generates SKILL.md file" do
      generator = described_class.new(
        kb_name: "test-kb",
        skill_description: "Test knowledge base",
        knowledge_files: [
          { summary: "API documentation", filename: "api.md" },
          { summary: "User guide", filename: "guide.md" }
        ]
      )

      generator.generate

      skill_file = File.join(Aircana.configuration.skills_dir, "test-kb", "SKILL.md")
      expect(File).to exist(skill_file)

      content = File.read(skill_file)
      expect(content).to include("name: Learn Test Kb")
      expect(content).to include("description: Test knowledge base")
      expect(content).to include("API documentation: [api.md](api.md)")
      expect(content).to include("User guide: [guide.md](guide.md)")
    end

    it "creates skill directory if it doesn't exist" do
      generator = described_class.new(kb_name: "new-kb")

      expect(Dir).not_to exist(File.join(Aircana.configuration.skills_dir, "new-kb"))

      generator.generate

      expect(Dir).to exist(File.join(Aircana.configuration.skills_dir, "new-kb"))
    end
  end
end
