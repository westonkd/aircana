# frozen_string_literal: true

require "spec_helper"
require "httparty"
require "reverse_markdown"

RSpec.describe Aircana::Contexts::Confluence do
  let(:confluence) { described_class.new }
  let(:mock_local_storage) { instance_double(Aircana::Contexts::Local) }

  before do
    # Configure Aircana with test values
    Aircana.configure do |config|
      config.confluence_base_url = "https://test.atlassian.net/wiki"
      config.confluence_api_token = "test-token-123"
    end

    # Mock the local storage
    allow(Aircana::Contexts::Local).to receive(:new).and_return(mock_local_storage)
    allow(mock_local_storage).to receive(:store_content)
  end

  describe "#fetch_pages_for" do
    context "when configuration is valid" do
      it "fetches pages with matching label and stores them as markdown" do
        # Mock search response
        search_response = double(success?: true)
        allow(search_response).to receive(:[]).with("results").and_return([
                                                                            { "id" => "123", "title" => "Test Page 1" },
                                                                            { "id" => "456", "title" => "Test Page 2" }
                                                                          ])
        allow(described_class).to receive(:get).with("/rest/api/search", anything).and_return(search_response)

        # Mock page content responses
        page1_response = double(success?: true)
        page2_response = double(success?: true)
        allow(page1_response).to receive(:dig).with("body", "storage",
                                                    "value").and_return("<h1>Test Content 1</h1><p>Some content</p>")
        allow(page2_response).to receive(:dig).with("body", "storage",
                                                    "value").and_return("<h1>Test Content 2</h1><p>More content</p>")

        allow(described_class).to receive(:get).with("/rest/api/content/123", anything).and_return(page1_response)
        allow(described_class).to receive(:get).with("/rest/api/content/456", anything).and_return(page2_response)

        # Mock markdown conversion
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content 1</h1><p>Some content</p>", github_flavored: true)
          .and_return("# Test Content 1\n\nSome content")
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content 2</h1><p>More content</p>", github_flavored: true)
          .and_return("# Test Content 2\n\nMore content")

        result = confluence.fetch_pages_for(agent: "test-agent")

        expect(result).to eq(2)
        expect(mock_local_storage).to have_received(:store_content).with(
          title: "Test Page 1",
          content: "# Test Content 1\n\nSome content",
          agent: "test-agent"
        )
        expect(mock_local_storage).to have_received(:store_content).with(
          title: "Test Page 2",
          content: "# Test Content 2\n\nMore content",
          agent: "test-agent"
        )
      end

      it "returns 0 when no pages are found" do
        search_response = double(success?: true)
        allow(search_response).to receive(:[]).with("results").and_return([])
        allow(described_class).to receive(:get).with("/rest/api/search", anything).and_return(search_response)

        result = confluence.fetch_pages_for(agent: "nonexistent-agent")

        expect(result).to eq(0)
        expect(mock_local_storage).not_to have_received(:store_content)
      end
    end

    context "when configuration is invalid" do
      it "raises error when base URL is not configured" do
        Aircana.configure { |config| config.confluence_base_url = nil }

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Confluence base URL not configured")
      end

      it "raises error when API token is not configured" do
        Aircana.configure { |config| config.confluence_api_token = "" }

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Confluence API token not configured")
      end
    end

    context "when API calls fail" do
      it "raises error when search fails" do
        allow(described_class).to receive(:get).with("/rest/api/search", anything).and_raise(StandardError,
                                                                                             "Network error")

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: Network error")
      end

      it "raises error when search returns non-success status" do
        search_response = double(success?: false, code: 401, message: "Unauthorized")
        allow(described_class).to receive(:get).with("/rest/api/search", anything).and_return(search_response)

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: HTTP 401: Unauthorized")
      end
    end
  end
end
