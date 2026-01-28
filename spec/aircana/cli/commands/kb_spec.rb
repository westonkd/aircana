# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Aircana::CLI::KB do
  let(:kb_name) { "test-kb" }

  around(:each) do |example|
    Dir.mktmpdir do |temp_dir|
      # Configure Aircana to use the temp directory
      original_skills_dir = Aircana.configuration.skills_dir
      original_kb_knowledge_dir = Aircana.configuration.kb_knowledge_dir
      original_plugin_root = Aircana.configuration.plugin_root
      original_hooks_dir = Aircana.configuration.hooks_dir

      skills_dir = File.join(temp_dir, ".claude", "skills")
      Aircana.configuration.skills_dir = skills_dir
      Aircana.configuration.kb_knowledge_dir = skills_dir
      Aircana.configuration.plugin_root = temp_dir
      Aircana.configuration.hooks_dir = File.join(temp_dir, "hooks")

      example.run

      # Restore original configuration
      Aircana.configuration.skills_dir = original_skills_dir
      Aircana.configuration.kb_knowledge_dir = original_kb_knowledge_dir
      Aircana.configuration.plugin_root = original_plugin_root
      Aircana.configuration.hooks_dir = original_hooks_dir
    end
  end

  describe ".list" do
    context "when no knowledge bases exist" do
      it "displays message indicating no KBs found" do
        expect(Aircana.human_logger).to receive(:info).with("No knowledge bases configured yet.")

        described_class.list
      end
    end

    context "when knowledge bases exist" do
      before do
        FileUtils.mkdir_p(Aircana.configuration.skills_dir)

        kb1_dir = File.join(Aircana.configuration.skills_dir, "kb-1")
        kb2_dir = File.join(Aircana.configuration.skills_dir, "kb-2")

        FileUtils.mkdir_p(kb1_dir)
        FileUtils.mkdir_p(kb2_dir)

        manifest1 = {
          "version" => "1.0",
          "name" => "kb-1",
          "sources" => []
        }

        manifest2 = {
          "version" => "1.0",
          "name" => "kb-2",
          "sources" => [{ "type" => "confluence", "pages" => [] }]
        }

        File.write(File.join(kb1_dir, "manifest.json"), JSON.generate(manifest1))
        File.write(File.join(kb2_dir, "manifest.json"), JSON.generate(manifest2))
      end

      it "displays list of knowledge bases" do
        expect(Aircana.human_logger).to receive(:info).with("Configured knowledge bases:")
        expect(Aircana.human_logger).to receive(:info).with("  1. kb-1 (0 sources)")
        expect(Aircana.human_logger).to receive(:info).with("  2. kb-2 (1 sources)")
        expect(Aircana.human_logger).to receive(:info).with("\nTotal: 2 knowledge bases")

        described_class.list
      end
    end
  end

  describe ".refresh" do
    let(:manifest) do
      {
        "version" => "1.0",
        "name" => kb_name,
        "sources" => [
          {
            "type" => "confluence",
            "pages" => [
              { "id" => "123", "summary" => "Test page" }
            ]
          }
        ]
      }
    end

    before do
      kb_dir = File.join(Aircana.configuration.skills_dir, kb_name)
      FileUtils.mkdir_p(kb_dir)
      File.write(File.join(kb_dir, "manifest.json"), JSON.generate(manifest))
    end

    it "refreshes KB from Confluence sources" do
      confluence = instance_double(Aircana::Contexts::Confluence)
      allow(Aircana::Contexts::Confluence).to receive(:new).and_return(confluence)

      # Return sources with actual data
      confluence_sources = [
        {
          "type" => "confluence",
          "pages" => [{ "id" => "123", "summary" => "Test page" }]
        }
      ]

      allow(confluence).to receive(:refresh_from_manifest).with(kb_name:).and_return(
        pages_count: 1,
        sources: confluence_sources
      )

      web = instance_double(Aircana::Contexts::Web)
      allow(Aircana::Contexts::Web).to receive(:new).and_return(web)
      allow(web).to receive(:refresh_web_sources).with(kb_name:).and_return(
        pages_count: 0,
        sources: []
      )

      allow(Aircana::Generators::SkillsGenerator).to receive(:from_manifest).with(kb_name).and_return(
        instance_double(Aircana::Generators::SkillsGenerator, generate: nil)
      )

      allow(Aircana::Generators::AgentsGenerator).to receive(:from_manifest).with(kb_name).and_return(
        instance_double(Aircana::Generators::AgentsGenerator, generate: nil)
      )

      # Expect update_manifest to be called since we have sources
      expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with(kb_name, confluence_sources)

      # Allow success messages (multiple may be logged)
      allow(Aircana.human_logger).to receive(:success)

      described_class.refresh(kb_name)
    end
  end

  describe ".add_url" do
    let(:url) { "https://example.com/guide" }

    before do
      kb_dir = File.join(Aircana.configuration.skills_dir, kb_name)
      FileUtils.mkdir_p(kb_dir)

      manifest = {
        "version" => "1.0",
        "name" => kb_name,
        "sources" => []
      }

      File.write(File.join(kb_dir, "manifest.json"), JSON.generate(manifest))
    end

    it "exits with error when KB doesn't exist" do
      expect(Aircana.human_logger).to receive(:error).with(/not found/)
      expect { described_class.add_url("nonexistent-kb", url) }.to raise_error(SystemExit)
    end

    it "adds URL to existing KB" do
      web = instance_double(Aircana::Contexts::Web)
      allow(Aircana::Contexts::Web).to receive(:new).and_return(web)
      allow(web).to receive(:fetch_url_for).with(kb_name: kb_name, url: url).and_return(
        { "url" => url, "summary" => "User guide" }
      )

      allow(Aircana::Generators::SkillsGenerator).to receive(:from_manifest).with(kb_name).and_return(
        instance_double(Aircana::Generators::SkillsGenerator, generate: nil)
      )

      allow(Aircana::Generators::AgentsGenerator).to receive(:from_manifest).with(kb_name).and_return(
        instance_double(Aircana::Generators::AgentsGenerator, generate: nil)
      )

      expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with(kb_name, anything)

      # Allow success messages (multiple may be logged)
      allow(Aircana.human_logger).to receive(:success)

      described_class.add_url(kb_name, url)
    end
  end

  describe ".refresh_all" do
    context "when no KBs exist" do
      it "displays message indicating no KBs" do
        expect(Aircana.human_logger).to receive(:info).with("No knowledge bases found to refresh.")

        described_class.refresh_all
      end
    end

    context "when KBs exist" do
      before do
        kb_dir = File.join(Aircana.configuration.skills_dir, "test-refresh-kb")
        FileUtils.mkdir_p(kb_dir)

        manifest = {
          "version" => "1.0",
          "name" => "test-refresh-kb",
          "sources" => [
            {
              "type" => "confluence",
              "pages" => [{ "id" => "123", "summary" => "Test page" }]
            }
          ]
        }

        File.write(File.join(kb_dir, "manifest.json"), JSON.generate(manifest))
      end

      it "refreshes all KBs" do
        confluence = instance_double(Aircana::Contexts::Confluence)
        allow(Aircana::Contexts::Confluence).to receive(:new).and_return(confluence)

        # Return sources with actual data so update_manifest is called
        confluence_sources = [
          {
            "type" => "confluence",
            "pages" => [{ "id" => "123", "summary" => "Test page" }]
          }
        ]

        allow(confluence).to receive(:refresh_from_manifest).and_return(
          pages_count: 1,
          sources: confluence_sources
        )

        web = instance_double(Aircana::Contexts::Web)
        allow(Aircana::Contexts::Web).to receive(:new).and_return(web)
        allow(web).to receive(:refresh_web_sources).and_return(
          pages_count: 0,
          sources: []
        )

        allow(Aircana::Generators::SkillsGenerator).to receive(:from_manifest).with("test-refresh-kb").and_return(
          instance_double(Aircana::Generators::SkillsGenerator, generate: nil)
        )

        allow(Aircana::Generators::AgentsGenerator).to receive(:from_manifest).with("test-refresh-kb").and_return(
          instance_double(Aircana::Generators::AgentsGenerator, generate: nil)
        )

        expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with("test-refresh-kb", confluence_sources)

        # Allow any success/info messages (multiple may be logged)
        allow(Aircana.human_logger).to receive(:success)
        allow(Aircana.human_logger).to receive(:info)

        described_class.refresh_all
      end
    end
  end

  describe "private methods" do
    describe ".kb_exists?" do
      it "returns true when KB directory exists" do
        kb_dir = File.join(Aircana.configuration.skills_dir, kb_name)
        FileUtils.mkdir_p(kb_dir)

        expect(described_class.send(:kb_exists?, kb_name)).to be true
      end

      it "returns false when KB directory doesn't exist" do
        expect(described_class.send(:kb_exists?, "nonexistent-kb")).to be false
      end
    end

    describe ".all_kbs" do
      it "returns empty array when no KBs exist" do
        expect(described_class.send(:all_kbs)).to eq([])
      end

      it "returns list of KB directories" do
        FileUtils.mkdir_p(File.join(Aircana.configuration.skills_dir, "kb-1"))
        FileUtils.mkdir_p(File.join(Aircana.configuration.skills_dir, "kb-2"))

        kbs = described_class.send(:all_kbs)
        expect(kbs).to contain_exactly("kb-1", "kb-2")
      end

      it "ignores files in skills directory" do
        FileUtils.mkdir_p(File.join(Aircana.configuration.skills_dir, "kb-1"))
        File.write(File.join(Aircana.configuration.skills_dir, "readme.md"), "test")

        kbs = described_class.send(:all_kbs)
        expect(kbs).to eq(["kb-1"])
      end
    end
  end
end
