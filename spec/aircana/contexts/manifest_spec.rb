# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Aircana::Contexts::Manifest do
  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory
      original_config = Aircana.configuration.kb_knowledge_dir
      Aircana.configuration.kb_knowledge_dir = File.join(temp_dir, ".claude", "skills")

      example.run

      # Restore original configuration
      Aircana.configuration.kb_knowledge_dir = original_config
    end
  end

  describe ".create_manifest" do
    let(:kb_name) { "test-kb" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "123", "summary" => "Test page summary" }
          ]
        }
      ]
    end

    it "creates a manifest file with proper structure" do
      result = described_class.create_manifest(kb_name, sources)

      expect(File).to exist(result)
      manifest = JSON.parse(File.read(result))

      expect(manifest["version"]).to eq("1.0")
      expect(manifest["name"]).to eq(kb_name)
      expect(manifest["sources"]).to eq(sources)
      expect(manifest).not_to have_key("kb_type")
    end

    it "creates the manifest directory if it doesn't exist" do
      expect(Dir).not_to exist(File.join(Aircana.configuration.kb_knowledge_dir, kb_name))

      described_class.create_manifest(kb_name, sources)

      expect(Dir).to exist(File.join(Aircana.configuration.kb_knowledge_dir, kb_name))
    end
  end

  describe ".update_manifest" do
    let(:kb_name) { "test-kb" }
    let(:original_sources) do
      [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "123", "summary" => "Original summary" }
          ]
        }
      ]
    end
    let(:updated_sources) do
      [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "456", "summary" => "Updated summary" }
          ]
        }
      ]
    end

    it "updates an existing manifest" do
      # Create initial manifest
      manifest_path = described_class.create_manifest(kb_name, original_sources)

      # Update manifest
      described_class.update_manifest(kb_name, updated_sources)

      # Verify update
      updated_data = JSON.parse(File.read(manifest_path))
      expect(updated_data["sources"]).to eq(updated_sources)
    end

    it "creates a new manifest if none exists" do
      manifest_path = described_class.update_manifest(kb_name, updated_sources)

      expect(File).to exist(manifest_path)
      manifest = JSON.parse(File.read(manifest_path))
      expect(manifest["sources"]).to eq(updated_sources)
    end
  end

  describe ".read_manifest" do
    let(:kb_name) { "test-kb" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "123", "summary" => "Test summary" }
          ]
        }
      ]
    end

    it "reads a valid manifest" do
      described_class.create_manifest(kb_name, sources)

      manifest = described_class.read_manifest(kb_name)

      expect(manifest["version"]).to eq("1.0")
      expect(manifest["name"]).to eq(kb_name)
      expect(manifest["sources"]).to eq(sources)
    end

    it "returns nil for non-existent manifest" do
      result = described_class.read_manifest("non-existent-kb")

      expect(result).to be_nil
    end

    it "returns nil for invalid JSON" do
      kb_dir = File.join(Aircana.configuration.kb_knowledge_dir, kb_name)
      FileUtils.mkdir_p(kb_dir)
      File.write(File.join(kb_dir, "manifest.json"), "invalid json")

      result = described_class.read_manifest(kb_name)

      expect(result).to be_nil
    end

    it "returns nil for manifest missing required fields" do
      kb_dir = File.join(Aircana.configuration.kb_knowledge_dir, kb_name)
      FileUtils.mkdir_p(kb_dir)
      File.write(File.join(kb_dir, "manifest.json"), JSON.generate({ "version" => "1.0" }))

      result = described_class.read_manifest(kb_name)

      expect(result).to be_nil
    end
  end

  describe ".sources_from_manifest" do
    let(:kb_name) { "test-kb" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "123", "summary" => "Test summary" }
          ]
        }
      ]
    end

    it "returns sources from valid manifest" do
      described_class.create_manifest(kb_name, sources)

      result = described_class.sources_from_manifest(kb_name)

      expect(result).to eq(sources)
    end

    it "returns empty array for non-existent manifest" do
      result = described_class.sources_from_manifest("non-existent-kb")

      expect(result).to eq([])
    end
  end

  describe ".manifest_exists?" do
    let(:kb_name) { "test-kb" }

    it "returns true when manifest exists" do
      described_class.create_manifest(kb_name, [])

      expect(described_class.manifest_exists?(kb_name)).to be true
    end

    it "returns false when manifest doesn't exist" do
      expect(described_class.manifest_exists?("non-existent-kb")).to be false
    end
  end

  describe "validation" do
    let(:kb_name) { "test-kb" }

    it "validates confluence sources require pages" do
      sources = [{ "type" => "confluence" }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /pages/)
    end

    it "validates unknown source types" do
      sources = [{ "type" => "unknown" }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /Unknown source type/)
    end

    it "validates confluence pages must be array" do
      sources = [{ "type" => "confluence", "pages" => "not-array" }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /pages must be an array/)
    end

    it "validates confluence page entries require id" do
      sources = [{ "type" => "confluence", "pages" => [{ "summary" => "Test" }] }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /Page entry missing required field: id/)
    end

    it "validates confluence page entries require summary" do
      sources = [{ "type" => "confluence", "pages" => [{ "id" => "123" }] }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /Page entry missing required field: summary/)
    end

    it "validates web sources require urls" do
      sources = [{ "type" => "web" }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /urls/)
    end

    it "validates web urls must be array" do
      sources = [{ "type" => "web", "urls" => "not-array" }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /urls must be an array/)
    end

    it "validates web url entries must be hashes" do
      sources = [{ "type" => "web", "urls" => ["not-a-hash"] }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry must be a hash/)
    end

    it "validates web url entries require url field" do
      sources = [{ "type" => "web", "urls" => [{ "summary" => "Test" }] }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry missing required field: url/)
    end

    it "validates web url entries require summary field" do
      sources = [{ "type" => "web", "urls" => [{ "url" => "https://example.com" }] }]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry missing required field: summary/)
    end

    it "accepts valid web sources with summaries" do
      sources = [
        {
          "type" => "web",
          "urls" => [
            { "url" => "https://example.com", "summary" => "Example website" }
          ]
        }
      ]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.not_to raise_error
    end

    it "accepts valid confluence sources with summaries" do
      sources = [
        {
          "type" => "confluence",
          "pages" => [
            { "id" => "123", "summary" => "Test page" }
          ]
        }
      ]

      expect do
        described_class.create_manifest(kb_name, sources)
      end.not_to raise_error
    end
  end
end
