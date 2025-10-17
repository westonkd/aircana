# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.global_dir).to eq(File.join(Dir.home, ".aircana"))
      expect(config.project_dir).to eq(Dir.pwd)
      expect(config.stream).to eq($stdout)
      expect(config.output_dir).to eq(File.join(Dir.home, ".aircana", "aircana.out"))
      expect(config.kb_knowledge_dir).to eq(File.join(Dir.pwd, ".claude", "skills"))
      expect(config.confluence_base_url).to be_nil
      expect(config.confluence_api_token).to be_nil
    end
  end

  describe "#kb_knowledge_dir" do
    it "returns the skills directory within plugin root" do
      expected_path = File.join(config.plugin_root, ".claude", "skills")
      expect(config.kb_knowledge_dir).to eq(expected_path)
    end
  end

  describe "#skills_dir" do
    it "returns the skills directory within plugin root" do
      expected_path = File.join(config.plugin_root, ".claude", "skills")
      expect(config.skills_dir).to eq(expected_path)
    end
  end

  describe "#hooks_dir" do
    it "returns the hooks directory within plugin root" do
      expected_path = File.join(config.plugin_root, "hooks")
      expect(config.hooks_dir).to eq(expected_path)
    end
  end

  describe "#scripts_dir" do
    it "returns the scripts directory within plugin root" do
      expected_path = File.join(config.plugin_root, "scripts")
      expect(config.scripts_dir).to eq(expected_path)
    end
  end

  describe "confluence configuration" do
    it "allows setting confluence_base_url" do
      config.confluence_base_url = "https://company.atlassian.net/wiki"
      expect(config.confluence_base_url).to eq("https://company.atlassian.net/wiki")
    end

    it "allows setting confluence_api_token" do
      config.confluence_api_token = "test-token-123"
      expect(config.confluence_api_token).to eq("test-token-123")
    end
  end

  describe "#plugin_root" do
    context "when AIRCANA_PLUGIN_ROOT is set" do
      around do |example|
        ClimateControl.modify(AIRCANA_PLUGIN_ROOT: "/custom/aircana/path") do
          example.run
        end
      end

      it "uses AIRCANA_PLUGIN_ROOT" do
        config = described_class.new
        expect(config.plugin_root).to eq("/custom/aircana/path")
      end
    end

    context "when CLAUDE_PLUGIN_ROOT is set" do
      around do |example|
        ClimateControl.modify(CLAUDE_PLUGIN_ROOT: "/custom/claude/path") do
          example.run
        end
      end

      it "uses CLAUDE_PLUGIN_ROOT" do
        config = described_class.new
        expect(config.plugin_root).to eq("/custom/claude/path")
      end
    end

    context "when AIRCANA_PLUGIN_ROOT takes precedence over CLAUDE_PLUGIN_ROOT" do
      around do |example|
        ClimateControl.modify(
          AIRCANA_PLUGIN_ROOT: "/aircana/path",
          CLAUDE_PLUGIN_ROOT: "/claude/path"
        ) do
          example.run
        end
      end

      it "uses AIRCANA_PLUGIN_ROOT" do
        config = described_class.new
        expect(config.plugin_root).to eq("/aircana/path")
      end
    end

    context "when no environment variables are set" do
      it "defaults to current directory" do
        expect(config.plugin_root).to eq(Dir.pwd)
      end
    end
  end
end
