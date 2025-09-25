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
        allow(mock_confluence).to receive(:fetch_pages_for).with(agent: "my-complex-agent-name").and_return({
                                                                                                              pages_count: 1, sources: []
                                                                                                            })

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
end
