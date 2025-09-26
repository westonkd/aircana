# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Aircana::Contexts::Manifest do
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

  describe ".create_manifest" do
    let(:agent) { "test-agent" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "label" => "test-agent",
          "pages" => [
            { "id" => "123", "title" => "Test Page", "last_updated" => "2024-01-01T00:00:00Z" }
          ]
        }
      ]
    end

    it "creates a manifest file with proper structure" do
      result = described_class.create_manifest(agent, sources)

      expect(File).to exist(result)
      manifest = JSON.parse(File.read(result))

      expect(manifest["version"]).to eq("1.0")
      expect(manifest["agent"]).to eq(agent)
      expect(manifest["sources"]).to eq(sources)
      expect(manifest["created"]).to be_a(String)
      expect(manifest["last_updated"]).to be_a(String)
    end

    it "creates the manifest directory if it doesn't exist" do
      expect(Dir).not_to exist(File.join(Aircana.configuration.agent_knowledge_dir, agent))

      described_class.create_manifest(agent, sources)

      expect(Dir).to exist(File.join(Aircana.configuration.agent_knowledge_dir, agent))
    end
  end

  describe ".update_manifest" do
    let(:agent) { "test-agent" }
    let(:original_sources) do
      [
        {
          "type" => "confluence",
          "label" => "test-agent",
          "pages" => [
            { "id" => "123", "title" => "Original Page", "last_updated" => "2024-01-01T00:00:00Z" }
          ]
        }
      ]
    end
    let(:updated_sources) do
      [
        {
          "type" => "confluence",
          "label" => "test-agent",
          "pages" => [
            { "id" => "123", "title" => "Updated Page", "last_updated" => "2024-02-01T00:00:00Z" }
          ]
        }
      ]
    end

    it "updates an existing manifest" do
      # Create initial manifest
      manifest_path = described_class.create_manifest(agent, original_sources)
      original_data = JSON.parse(File.read(manifest_path))

      # Update manifest
      sleep 1 # Ensure timestamp changes
      described_class.update_manifest(agent, updated_sources)

      # Verify update
      updated_data = JSON.parse(File.read(manifest_path))
      expect(updated_data["sources"]).to eq(updated_sources)
      expect(updated_data["created"]).to eq(original_data["created"])
      expect(updated_data["last_updated"]).not_to eq(original_data["last_updated"])
    end

    it "creates a new manifest if none exists" do
      manifest_path = described_class.update_manifest(agent, updated_sources)

      expect(File).to exist(manifest_path)
      manifest = JSON.parse(File.read(manifest_path))
      expect(manifest["sources"]).to eq(updated_sources)
    end
  end

  describe ".read_manifest" do
    let(:agent) { "test-agent" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "label" => "test-agent",
          "pages" => [
            { "id" => "123", "title" => "Test Page", "last_updated" => "2024-01-01T00:00:00Z" }
          ]
        }
      ]
    end

    it "reads a valid manifest" do
      described_class.create_manifest(agent, sources)

      manifest = described_class.read_manifest(agent)

      expect(manifest["version"]).to eq("1.0")
      expect(manifest["agent"]).to eq(agent)
      expect(manifest["sources"]).to eq(sources)
    end

    it "returns nil for non-existent manifest" do
      result = described_class.read_manifest("non-existent-agent")

      expect(result).to be_nil
    end

    it "returns nil for invalid JSON" do
      agent_dir = File.join(Aircana.configuration.agent_knowledge_dir, agent)
      FileUtils.mkdir_p(agent_dir)
      File.write(File.join(agent_dir, "manifest.json"), "invalid json")

      result = described_class.read_manifest(agent)

      expect(result).to be_nil
    end

    it "returns nil for manifest missing required fields" do
      agent_dir = File.join(Aircana.configuration.agent_knowledge_dir, agent)
      FileUtils.mkdir_p(agent_dir)
      File.write(File.join(agent_dir, "manifest.json"), JSON.generate({ "version" => "1.0" }))

      result = described_class.read_manifest(agent)

      expect(result).to be_nil
    end
  end

  describe ".sources_from_manifest" do
    let(:agent) { "test-agent" }
    let(:sources) do
      [
        {
          "type" => "confluence",
          "label" => "test-agent",
          "pages" => [
            { "id" => "123", "title" => "Test Page", "last_updated" => "2024-01-01T00:00:00Z" }
          ]
        }
      ]
    end

    it "returns sources from valid manifest" do
      described_class.create_manifest(agent, sources)

      result = described_class.sources_from_manifest(agent)

      expect(result).to eq(sources)
    end

    it "returns empty array for non-existent manifest" do
      result = described_class.sources_from_manifest("non-existent-agent")

      expect(result).to eq([])
    end
  end

  describe ".manifest_exists?" do
    let(:agent) { "test-agent" }

    it "returns true when manifest exists" do
      described_class.create_manifest(agent, [])

      expect(described_class.manifest_exists?(agent)).to be true
    end

    it "returns false when manifest doesn't exist" do
      expect(described_class.manifest_exists?("non-existent-agent")).to be false
    end
  end

  describe "validation" do
    let(:agent) { "test-agent" }

    it "validates confluence sources require label" do
      sources = [{ "type" => "confluence" }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /label/)
    end

    it "validates unknown source types" do
      sources = [{ "type" => "unknown" }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /Unknown source type/)
    end

    it "validates confluence pages must be array" do
      sources = [{ "type" => "confluence", "label" => "test", "pages" => "not-array" }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /pages must be an array/)
    end

    it "validates web sources require urls" do
      sources = [{ "type" => "web" }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /urls/)
    end

    it "validates web urls must be array" do
      sources = [{ "type" => "web", "urls" => "not-array" }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /urls must be an array/)
    end

    it "validates web url entries must be hashes" do
      sources = [{ "type" => "web", "urls" => ["not-a-hash"] }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry must be a hash/)
    end

    it "validates web url entries require url field" do
      sources = [{ "type" => "web", "urls" => [{ "title" => "Test" }] }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry missing required field: url/)
    end

    it "validates web url entries require title field" do
      sources = [{ "type" => "web", "urls" => [{ "url" => "https://example.com" }] }]

      expect do
        described_class.create_manifest(agent, sources)
      end.to raise_error(Aircana::Contexts::ManifestError, /URL entry missing required field: title/)
    end

    it "accepts valid web sources" do
      sources = [
        {
          "type" => "web",
          "urls" => [
            { "url" => "https://example.com", "title" => "Example", "last_fetched" => "2024-01-01T00:00:00Z" }
          ]
        }
      ]

      expect do
        described_class.create_manifest(agent, sources)
      end.not_to raise_error
    end
  end
end
