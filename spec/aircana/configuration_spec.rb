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
      expect(config.agent_knowledge_dir).to eq(File.join(Dir.pwd, ".aircana", "agents"))
      expect(config.confluence_base_url).to be_nil
      expect(config.confluence_api_token).to be_nil
    end
  end

  describe "#relevant_project_files_dir" do
    it "returns the .aircana/relevant_files directory within project_dir" do
      expected_path = File.join(config.project_dir, ".aircana", "relevant_files")
      expect(config.relevant_project_files_dir).to eq(expected_path)
    end
  end

  describe "#agent_knowledge_dir" do
    it "returns the .aircana/agents directory within project_dir" do
      expected_path = File.join(config.project_dir, ".aircana", "agents")
      expect(config.agent_knowledge_dir).to eq(expected_path)
    end
  end

  describe "#hooks_dir" do
    it "returns the .aircana/hooks directory within project_dir" do
      expected_path = File.join(config.project_dir, ".aircana", "hooks")
      expect(config.hooks_dir).to eq(expected_path)
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
end
