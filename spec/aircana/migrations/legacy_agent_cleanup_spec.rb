# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Aircana::Migrations::LegacyAgentCleanup do
  let(:generated_agent) do
    <<~AGENT
      ---
      name: demo
      description: Discover critical context for demo
      model: inherit
      color: cyan
      ---

      Use the skill "Learn Demo" to learn your domain, then perform the requested task.
    AGENT
  end

  let(:hand_written_agent) do
    <<~AGENT
      ---
      name: keep
      description: A bespoke agent someone wrote by hand
      ---

      Do something clever that aircana never generated.
    AGENT
  end

  around do |example|
    Dir.mktmpdir do |temp_dir|
      original_plugin_root = Aircana.configuration.plugin_root

      @plugin_root = temp_dir
      @agents_dir = File.join(temp_dir, "agents")
      FileUtils.mkdir_p(@agents_dir)
      FileUtils.mkdir_p(File.join(temp_dir, ".claude-plugin"))
      File.write(File.join(temp_dir, ".claude-plugin", "plugin.json"), '{"name":"demo","version":"1.0.0"}')
      Aircana.configuration.plugin_root = temp_dir

      example.run

      Aircana.configuration.plugin_root = original_plugin_root
    end
  end

  before do
    allow(Aircana.human_logger).to receive(:info)
    allow(Aircana.human_logger).to receive(:warn)
  end

  describe ".run" do
    it "deletes an agent file aircana generated" do
      path = File.join(@agents_dir, "demo.md")
      File.write(path, generated_agent)

      described_class.run("demo")

      expect(File).not_to exist(path)
    end

    it "leaves a hand-written agent file alone" do
      path = File.join(@agents_dir, "keep.md")
      File.write(path, hand_written_agent)

      described_class.run("keep")

      expect(File.read(path)).to eq(hand_written_agent)
    end

    it "removes the legacy directory once it is empty" do
      File.write(File.join(@agents_dir, "demo.md"), generated_agent)

      described_class.run("demo")

      expect(Dir).not_to exist(@agents_dir)
    end

    it "keeps the legacy directory when other files remain" do
      File.write(File.join(@agents_dir, "demo.md"), generated_agent)
      File.write(File.join(@agents_dir, "keep.md"), hand_written_agent)

      described_class.run("demo")

      expect(Dir).to exist(@agents_dir)
      expect(File).to exist(File.join(@agents_dir, "keep.md"))
    end

    it "does nothing when there is no legacy agent file" do
      expect { described_class.run("absent") }.not_to raise_error
      expect(Dir).to exist(@agents_dir)
    end
  end

  describe ".legacy_agents_dir" do
    it "resolves to agents/ in plugin mode" do
      expect(described_class.legacy_agents_dir).to eq(File.join(@plugin_root, "agents"))
    end

    it "resolves to .claude/agents/ outside plugin mode" do
      FileUtils.rm_rf(File.join(@plugin_root, ".claude-plugin"))

      expect(described_class.legacy_agents_dir).to eq(File.join(@plugin_root, ".claude", "agents"))
    end
  end
end
