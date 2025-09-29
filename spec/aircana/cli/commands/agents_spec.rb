# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::CLI::Agents do
  let(:mock_confluence) { instance_double(Aircana::Contexts::Confluence) }

  before do
    # Mock human logger to capture output
    @log_messages = []
    human_logger_double = instance_double("HumanLogger")
    allow(human_logger_double).to receive(:info) { |msg| @log_messages << [:info, msg] }
    allow(human_logger_double).to receive(:error) { |msg| @log_messages << [:error, msg] }
    allow(human_logger_double).to receive(:success) { |msg| @log_messages << [:success, msg] }
    allow(Aircana).to receive(:human_logger).and_return(human_logger_double)

    # Mock the Confluence context
    allow(Aircana::Contexts::Confluence).to receive(:new).and_return(mock_confluence)

    # Mock manifest existence to false by default (fallback to fetch_pages_for)
    allow(Aircana::Contexts::Manifest).to receive(:manifest_exists?).and_return(false)
  end

  describe ".refresh" do
    context "when refresh is successful" do
      it "normalizes agent name and fetches pages" do
        allow(mock_confluence).to receive(:fetch_pages_for).with(agent: "test-agent").and_return({ pages_count: 3,
                                                                                                   sources: [] })

        described_class.refresh("Test Agent")

        expect(mock_confluence).to have_received(:fetch_pages_for).with(agent: "test-agent")
        expect(@log_messages).to include([:success, "Successfully refreshed 3 pages for agent 'test-agent'"])
      end

      it "handles agent names with various formats" do
        allow(mock_confluence).to receive(:fetch_pages_for).with(agent: "my-complex-agent-name").and_return(
          { pages_count: 1, sources: [] }
        )

        described_class.refresh("My Complex Agent Name")

        expect(mock_confluence).to have_received(:fetch_pages_for).with(agent: "my-complex-agent-name")
        expect(@log_messages).to include([:success, "Successfully refreshed 1 pages for agent 'my-complex-agent-name'"])
      end

      it "handles case when no pages are found" do
        allow(mock_confluence).to receive(:fetch_pages_for).with(agent: "empty-agent").and_return({ pages_count: 0,
                                                                                                    sources: [] })

        described_class.refresh("empty-agent")

        expect(mock_confluence).to have_received(:fetch_pages_for).with(agent: "empty-agent")
        expected_message = "No pages found for agent 'empty-agent'. " \
                           "Make sure pages are labeled with 'empty-agent' in Confluence."
        expect(@log_messages).to include([:info, expected_message])
      end
    end

    context "when Confluence configuration is invalid" do
      it "logs error and exits when configuration is missing" do
        allow(mock_confluence).to receive(:fetch_pages_for).and_raise(Aircana::Error,
                                                                      "Confluence base URL not configured")

        expect { described_class.refresh("test-agent") }.to raise_error(SystemExit)
        expected_message = "Failed to refresh agent 'test-agent': Confluence base URL not configured"
        expect(@log_messages).to include([:error, expected_message])
      end
    end

    context "when API calls fail" do
      it "logs error and exits when Confluence API fails" do
        allow(mock_confluence).to receive(:fetch_pages_for).and_raise(Aircana::Error, "HTTP 401: Unauthorized")

        expect { described_class.refresh("test-agent") }.to raise_error(SystemExit)
        expect(@log_messages).to include([:error, "Failed to refresh agent 'test-agent': HTTP 401: Unauthorized"])
      end

      it "logs error and exits when network error occurs" do
        error_message = "Failed to fetch pages from Confluence: Network error"
        allow(mock_confluence).to receive(:fetch_pages_for).and_raise(Aircana::Error, error_message)

        expect { described_class.refresh("test-agent") }.to raise_error(SystemExit)
        expected_message = "Failed to refresh agent 'test-agent': #{error_message}"
        expect(@log_messages).to include([:error, expected_message])
      end
    end
  end

  describe ".add_url" do
    let(:mock_web) { instance_double(Aircana::Contexts::Web) }
    let(:agent) { "test-agent" }
    let(:url) { "https://example.com/test" }
    let(:url_metadata) do
      {
        "url" => url,
        "title" => "Test Page",
        "last_fetched" => "2024-01-01T00:00:00Z"
      }
    end

    before do
      allow(Aircana::Contexts::Web).to receive(:new).and_return(mock_web)
      allow(described_class).to receive(:agent_exists?).with(agent).and_return(true)
    end

    context "when agent exists and URL fetch is successful" do
      before do
        allow(mock_web).to receive(:fetch_url_for).with(agent: agent, url: url).and_return(url_metadata)
        allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest).with(agent).and_return([])
        allow(Aircana::Contexts::Manifest).to receive(:update_manifest)
      end

      it "adds URL to agent's knowledge base" do
        described_class.add_url(agent, url)

        expect(mock_web).to have_received(:fetch_url_for).with(agent: agent, url: url)
        expect(@log_messages).to include([:success, "Successfully added URL to agent '#{agent}'"])
      end

      it "updates the manifest with the new URL" do
        described_class.add_url(agent, url)

        expected_sources = [{ "type" => "web", "urls" => [url_metadata] }]
        expect(Aircana::Contexts::Manifest).to have_received(:update_manifest).with(agent, expected_sources)
      end

      context "when agent already has web sources" do
        let(:existing_url_metadata) do
          {
            "url" => "https://existing.com",
            "title" => "Existing Page",
            "last_fetched" => "2023-12-01T00:00:00Z"
          }
        end
        let(:existing_sources) do
          [
            { "type" => "web", "urls" => [existing_url_metadata] },
            { "type" => "confluence", "label" => "test-agent", "pages" => [] }
          ]
        end

        before do
          allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest)
            .with(agent).and_return(existing_sources)
        end

        it "adds to existing web source" do
          described_class.add_url(agent, url)

          expected_web_urls = [existing_url_metadata, url_metadata]
          expected_sources = [
            { "type" => "confluence", "label" => "test-agent", "pages" => [] },
            { "type" => "web", "urls" => expected_web_urls }
          ]
          expect(Aircana::Contexts::Manifest).to have_received(:update_manifest)
            .with(agent, expected_sources)
        end
      end
    end

    context "when agent does not exist" do
      before do
        allow(described_class).to receive(:agent_exists?).with("nonexistent").and_return(false)
      end

      it "logs error and exits" do
        expect { described_class.add_url("nonexistent", url) }.to raise_error(SystemExit)
        expect(@log_messages).to include(
          [:error, "Agent 'nonexistent' not found. Use 'aircana agents list' to see available agents."]
        )
      end
    end

    context "when URL fetch fails" do
      before do
        allow(mock_web).to receive(:fetch_url_for).with(agent: agent, url: url).and_return(nil)
      end

      it "logs error and exits" do
        expect { described_class.add_url(agent, url) }.to raise_error(SystemExit)
        expect(@log_messages).to include([:error, "Failed to fetch URL: #{url}"])
      end
    end

    context "when web context raises an error" do
      before do
        allow(mock_web).to receive(:fetch_url_for)
          .with(agent: agent, url: url)
          .and_raise(Aircana::Error, "Invalid URL format")
      end

      it "handles error gracefully" do
        expect { described_class.add_url(agent, url) }.to raise_error(SystemExit)
        expect(@log_messages).to include([:error, "Failed to add URL: Invalid URL format"])
      end
    end
  end

  describe ".refresh with mixed sources" do
    let(:mock_web) { instance_double(Aircana::Contexts::Web) }
    let(:agent) { "test-agent" }
    let(:confluence_sources) do
      [
        {
          "type" => "confluence",
          "label" => agent,
          "pages" => [
            { "id" => "123", "title" => "Confluence Page" }
          ]
        }
      ]
    end
    let(:web_sources) do
      [
        {
          "type" => "web",
          "urls" => [
            {
              "url" => "https://example.com/test",
              "title" => "Web Page",
              "last_fetched" => "2024-01-01T00:00:00Z"
            }
          ]
        }
      ]
    end

    before do
      allow(Aircana::Contexts::Web).to receive(:new).and_return(mock_web)
      allow(Aircana::Contexts::Manifest).to receive(:manifest_exists?).with(agent).and_return(true)
    end

    it "preserves both Confluence and Web sources during refresh" do
      # Mock confluence refresh to return confluence sources
      allow(mock_confluence).to receive(:refresh_from_manifest).with(agent: agent)
                                                               .and_return({ pages_count: 1,
                                                                             sources: confluence_sources })

      # Mock web refresh to return web sources
      allow(mock_web).to receive(:refresh_web_sources).with(agent: agent)
                                                      .and_return({ pages_count: 1, sources: web_sources })

      # Mock manifest update to capture the combined sources
      combined_sources = confluence_sources + web_sources
      expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with(agent, combined_sources)

      result = described_class.send(:perform_manifest_aware_refresh, agent)

      expect(result[:pages_count]).to eq(2)
      expect(result[:sources]).to eq(combined_sources)
      expect(@log_messages).to include([:success, "Successfully refreshed 2 pages for agent '#{agent}'"])
    end

    it "handles case where only web sources exist" do
      # Mock confluence refresh to return empty result
      allow(mock_confluence).to receive(:refresh_from_manifest).with(agent: agent)
                                                               .and_return({ pages_count: 0, sources: [] })

      # Mock web refresh to return web sources
      allow(mock_web).to receive(:refresh_web_sources).with(agent: agent)
                                                      .and_return({ pages_count: 1, sources: web_sources })

      # Should still update manifest with just web sources
      expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with(agent, web_sources)

      result = described_class.send(:perform_manifest_aware_refresh, agent)

      expect(result[:pages_count]).to eq(1)
      expect(result[:sources]).to eq(web_sources)
    end

    it "handles case where only confluence sources exist" do
      # Mock confluence refresh to return confluence sources
      allow(mock_confluence).to receive(:refresh_from_manifest).with(agent: agent)
                                                               .and_return({ pages_count: 1,
                                                                             sources: confluence_sources })

      # Mock web refresh to return empty result
      allow(mock_web).to receive(:refresh_web_sources).with(agent: agent)
                                                      .and_return({ pages_count: 0, sources: [] })

      # Should update manifest with just confluence sources
      expect(Aircana::Contexts::Manifest).to receive(:update_manifest).with(agent, confluence_sources)

      result = described_class.send(:perform_manifest_aware_refresh, agent)

      expect(result[:pages_count]).to eq(1)
      expect(result[:sources]).to eq(confluence_sources)
    end
  end

  describe "normalize_string (private method)" do
    it "normalizes agent names consistently" do
      # Test the same normalization logic used in create and refresh
      expect(described_class.send(:normalize_string, "Test Agent")).to eq("test-agent")
      expect(described_class.send(:normalize_string, "My Complex Agent Name")).to eq("my-complex-agent-name")
      expect(described_class.send(:normalize_string, "  Spaced  Out  ")).to eq("spaced--out")
      expect(described_class.send(:normalize_string, "UPPERCASE")).to eq("uppercase")
      expect(described_class.send(:normalize_string, "already-normalized")).to eq("already-normalized")
    end
  end

  describe ".sync_all" do
    let(:agent_knowledge_dir) { "/path/to/agents" }
    let(:configuration) { instance_double("Configuration", agent_knowledge_dir: agent_knowledge_dir) }

    before do
      allow(Aircana).to receive(:configuration).and_return(configuration)
    end

    context "when no agents exist" do
      it "logs appropriate message and returns" do
        allow(Dir).to receive(:exist?).with(agent_knowledge_dir).and_return(false)

        described_class.sync_all

        expect(@log_messages).to include([:info, "No agents found to sync."])
      end
    end

    context "when agents directory is empty" do
      it "logs appropriate message and returns" do
        allow(Dir).to receive(:exist?).with(agent_knowledge_dir).and_return(true)
        allow(Dir).to receive(:entries).with(agent_knowledge_dir).and_return(["..", "."])

        described_class.sync_all

        expect(@log_messages).to include([:info, "No agents found to sync."])
      end
    end

    context "when agents exist" do
      let(:agent_folders) { %w[agent1 agent2 agent3] }

      before do
        allow(Dir).to receive(:exist?).with(agent_knowledge_dir).and_return(true)
        allow(Dir).to receive(:entries).with(agent_knowledge_dir).and_return(["..", ".", *agent_folders])
        allow(File).to receive(:directory?).and_return(false)
        agent_folders.each do |folder|
          allow(File).to receive(:directory?).with(File.join(agent_knowledge_dir, folder)).and_return(true)
        end
      end

      it "syncs all agents successfully" do
        # Mock successful sync for all agents
        agent_folders.each do |agent|
          allow(described_class).to receive(:perform_manifest_aware_refresh).with(agent)
                                                                            .and_return({ pages_count: 2, sources: [] })
        end

        described_class.sync_all

        expect(@log_messages).to include([:info, "Starting sync for 3 agent(s)..."])
        agent_folders.each do |agent|
          expect(@log_messages).to include([:info, "Syncing agent '#{agent}'..."])
        end
        expect(@log_messages).to include([:info, "=== Sync All Summary ==="])
        expect(@log_messages).to include([:success, "✓ Successful: 3/3 agents"])
        expect(@log_messages).to include([:success, "✓ Total pages refreshed: 6"])
      end

      it "handles mixed success and failure scenarios" do
        # Mock successful sync for first agent
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent1")
                                                                          .and_return({ pages_count: 3, sources: [] })

        # Mock failure for second agent
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent2")
                                                                          .and_raise(Aircana::Error, "Network error")

        # Mock successful sync for third agent
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent3")
                                                                          .and_return({ pages_count: 1, sources: [] })

        described_class.sync_all

        expect(@log_messages).to include([:info, "Starting sync for 3 agent(s)..."])
        expect(@log_messages).to include([:info, "Syncing agent 'agent1'..."])
        expect(@log_messages).to include([:info, "Syncing agent 'agent2'..."])
        expect(@log_messages).to include([:error, "Failed to sync agent 'agent2': Network error"])
        expect(@log_messages).to include([:info, "Syncing agent 'agent3'..."])
        expect(@log_messages).to include([:success, "✓ Successful: 2/3 agents"])
        expect(@log_messages).to include([:success, "✓ Total pages refreshed: 4"])
        expect(@log_messages).to include([:error, "✗ Failed: 1 agents"])
        expect(@log_messages).to include([:info, "Failed agents:"])
        expect(@log_messages).to include([:error, "  - agent2: Network error"])
      end

      it "continues syncing remaining agents when some fail" do
        # Mock failure for all agents with different errors
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent1")
                                                                          .and_raise(Aircana::Error, "Config error")
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent2")
                                                                          .and_raise(Aircana::Error, "Network error")
        allow(described_class).to receive(:perform_manifest_aware_refresh).with("agent3")
                                                                          .and_raise(Aircana::Error, "Auth error")

        described_class.sync_all

        expect(@log_messages).to include([:success, "✓ Successful: 0/3 agents"])
        expect(@log_messages).to include([:error, "✗ Failed: 3 agents"])
        expect(@log_messages).to include([:error, "  - agent1: Config error"])
        expect(@log_messages).to include([:error, "  - agent2: Network error"])
        expect(@log_messages).to include([:error, "  - agent3: Auth error"])
      end
    end
  end
end
