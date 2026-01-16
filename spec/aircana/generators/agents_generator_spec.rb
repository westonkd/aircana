# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::Generators::AgentsGenerator do
  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory
      original_agents_dir = Aircana.configuration.agents_dir
      Aircana.configuration.agents_dir = File.join(temp_dir, ".claude", "agents")

      example.run

      # Restore original configuration
      Aircana.configuration.agents_dir = original_agents_dir
    end
  end

  describe "#initialize" do
    it "creates generator with required parameters" do
      generator = described_class.new(
        kb_name: "test-kb",
        agent_description: "Test description",
        color: "blue"
      )

      expect(generator.kb_name).to eq("test-kb")
      expect(generator.agent_description).to eq("Test description")
      expect(generator.color).to eq("blue")
    end

    it "generates default agent description from kb_name" do
      generator = described_class.new(kb_name: "my-test-kb")

      expect(generator.agent_description).to eq("Discover critical context for my test kb")
    end

    it "generates random color when not provided" do
      generator = described_class.new(kb_name: "test-kb")

      expect(described_class::PRESET_COLORS).to include(generator.color)
    end

    it "uses provided color when specified" do
      generator = described_class.new(kb_name: "test-kb", color: "purple")

      expect(generator.color).to eq("purple")
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
              { "id" => "123456", "summary" => "API documentation" }
            ]
          },
          {
            "type" => "web",
            "urls" => [
              { "url" => "https://example.com/guide", "summary" => "User guide" }
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
      expect(generator.agent_description).to eq("Discover critical context for test kb from 2 knowledge sources")
    end

    it "generates random color for new agent" do
      generator = described_class.from_manifest(kb_name)

      expect(described_class::PRESET_COLORS).to include(generator.color)
    end

    it "preserves existing agent color when file exists" do
      # Create an existing agent file with a specific color
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      existing_agent_content = <<~AGENT
        ---
        name: test-kb
        description: Old description
        model: inherit
        color: cyan
        ---

        Use the skill "Learn Test Kb" to learn your domain, then perform the requested task.
      AGENT

      File.write(agent_path, existing_agent_content)

      generator = described_class.from_manifest(kb_name)

      expect(generator.color).to eq("cyan")
    end

    it "generates new color when existing file has no color" do
      # Create an existing agent file without a color field
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      existing_agent_content = <<~AGENT
        ---
        name: test-kb
        description: Old description
        ---

        Some content
      AGENT

      File.write(agent_path, existing_agent_content)

      generator = described_class.from_manifest(kb_name)

      expect(described_class::PRESET_COLORS).to include(generator.color)
    end

    it "raises error when manifest doesn't exist" do
      allow(Aircana::Contexts::Manifest).to receive(:read_manifest)
        .with("nonexistent-kb").and_return(nil)

      expect do
        described_class.from_manifest("nonexistent-kb")
      end.to raise_error(Aircana::Error, "No manifest found for knowledge base 'nonexistent-kb'")
    end
  end

  describe ".read_existing_color" do
    let(:kb_name) { "test-kb" }

    it "returns nil when agent file doesn't exist" do
      color = described_class.read_existing_color(kb_name)

      expect(color).to be_nil
    end

    it "extracts color from existing agent file" do
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      agent_content = <<~AGENT
        ---
        name: test-kb
        description: Test agent
        model: inherit
        color: magenta
        ---

        Agent content
      AGENT

      File.write(agent_path, agent_content)

      color = described_class.read_existing_color(kb_name)

      expect(color).to eq("magenta")
    end

    it "handles different color formats in frontmatter" do
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      # Test with spaces around color value
      agent_content = <<~AGENT
        ---
        name: test-kb
        color:   teal   
        ---
      AGENT

      File.write(agent_path, agent_content)

      color = described_class.read_existing_color(kb_name)

      expect(color).to eq("teal")
    end

    it "returns nil when color field is missing" do
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      agent_content = <<~AGENT
        ---
        name: test-kb
        description: No color here
        ---
      AGENT

      File.write(agent_path, agent_content)

      color = described_class.read_existing_color(kb_name)

      expect(color).to be_nil
    end

    it "returns nil when file is malformed" do
      agent_dir = Aircana.configuration.agents_dir
      FileUtils.mkdir_p(agent_dir)
      agent_path = File.join(agent_dir, "#{kb_name}.md")

      File.write(agent_path, "This is not valid frontmatter")

      color = described_class.read_existing_color(kb_name)

      expect(color).to be_nil
    end
  end

  describe ".generate_agent_description_from_manifest" do
    it "generates description with source count" do
      manifest = {
        "sources" => [
          { "type" => "confluence" },
          { "type" => "web" }
        ]
      }

      description = described_class.generate_agent_description_from_manifest(manifest, "my-test-kb")

      expect(description).to eq("Discover critical context for my test kb from 2 knowledge sources")
    end

    it "handles manifest with no sources" do
      manifest = { "sources" => [] }

      description = described_class.generate_agent_description_from_manifest(manifest, "empty-kb")

      expect(description).to eq("Discover critical context for empty kb from 0 knowledge sources")
    end

    it "formats kb name with spaces" do
      manifest = { "sources" => [{ "type" => "confluence" }] }

      description = described_class.generate_agent_description_from_manifest(manifest, "docker-production-guide")

      expect(description).to eq("Discover critical context for docker production guide from 1 knowledge sources")
    end
  end

  describe "#generate" do
    it "generates agent markdown file with correct structure" do
      generator = described_class.new(
        kb_name: "test-kb",
        agent_description: "Test agent for documentation",
        color: "blue"
      )

      generator.generate

      agent_file = File.join(Aircana.configuration.agents_dir, "test-kb.md")
      expect(File).to exist(agent_file)

      content = File.read(agent_file)
      expect(content).to include("name: test-kb")
      expect(content).to include("description: Test agent for documentation")
      expect(content).to include("color: blue")
      expect(content).to include("Use the skill \"Learn Test Kb\"")
    end

    it "creates agent directory if it doesn't exist" do
      generator = described_class.new(kb_name: "new-kb")

      expect(Dir).not_to exist(Aircana.configuration.agents_dir)

      generator.generate

      expect(Dir).to exist(Aircana.configuration.agents_dir)
    end
  end

  describe "color persistence across regeneration" do
    let(:kb_name) { "test-kb" }
    let(:manifest) do
      {
        "version" => "1.0",
        "name" => kb_name,
        "kb_type" => "local",
        "sources" => [
          { "type" => "confluence", "pages" => [{ "id" => "123", "summary" => "Doc" }] }
        ]
      }
    end

    before do
      allow(Aircana::Contexts::Manifest).to receive(:read_manifest)
        .with(kb_name).and_return(manifest)
    end

    it "maintains the same color across multiple regenerations" do
      # First generation - creates agent with random color
      generator1 = described_class.from_manifest(kb_name)
      generator1.generate

      first_color = generator1.color

      # Second generation - should preserve the color
      generator2 = described_class.from_manifest(kb_name)
      generator2.generate

      expect(generator2.color).to eq(first_color)

      # Third generation - should still preserve the color
      generator3 = described_class.from_manifest(kb_name)
      generator3.generate

      expect(generator3.color).to eq(first_color)
    end
  end
end
