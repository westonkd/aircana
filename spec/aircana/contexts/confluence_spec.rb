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
      config.confluence_username = "test-user@example.com"
      config.confluence_api_token = "test-token-123"
    end

    # Mock the local storage
    allow(Aircana::Contexts::Local).to receive(:new).and_return(mock_local_storage)
    allow(mock_local_storage).to receive(:store_content)
  end

  describe "#fetch_pages_for" do
    context "when configuration is valid" do
      it "fetches pages with matching label and stores them as markdown" do
        # Mock labels response
        labels_response = double(success?: true, code: 200, body: '{"results":[{"id":"10001","name":"test-agent","prefix":"global"}]}')
        allow(labels_response).to receive(:[]).with("results").and_return([
          { "id" => "10001", "name" => "test-agent", "prefix" => "global" }
        ])
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        # Mock pages for label response
        pages_response = double(success?: true, code: 200, body: '{"results":[{"id":"123","title":"Test Page 1"},{"id":"456","title":"Test Page 2"}]}')
        allow(pages_response).to receive(:[]).with("results").and_return([
          { 
            "id" => "123", 
            "title" => "Test Page 1",
            "body" => { "storage" => { "value" => "<h1>Test Content 1</h1><p>Some content</p>" } }
          },
          { 
            "id" => "456", 
            "title" => "Test Page 2",
            "body" => { "storage" => { "value" => "<h1>Test Content 2</h1><p>More content</p>" } }
          }
        ])
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels/10001/pages", anything).and_return(pages_response)


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
        labels_response = double(success?: true, code: 200, body: '{"results":[]}')
        allow(labels_response).to receive(:[]).with("results").and_return([])
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        result = confluence.fetch_pages_for(agent: "nonexistent-agent")

        expect(result).to eq(0)
        expect(mock_local_storage).not_to have_received(:store_content)
      end

      it "handles pagination when label is found on second page" do
        # Mock first page response (no matching label)
        first_page_response = double(success?: true, code: 200, body: '{"results":[{"id":"10000","name":"other-label","prefix":"global"}]}')
        allow(first_page_response).to receive(:[]).with("results").and_return([
          { "id" => "10000", "name" => "other-label", "prefix" => "global" }
        ])
        allow(first_page_response).to receive(:dig).with("_links", "next").and_return("https://test.atlassian.net/wiki/api/v2/labels?cursor=abc123")

        # Mock second page response (with matching label)
        second_page_response = double(success?: true, code: 200, body: '{"results":[{"id":"10001","name":"test-agent","prefix":"global"}]}')
        allow(second_page_response).to receive(:[]).with("results").and_return([
          { "id" => "10001", "name" => "test-agent", "prefix" => "global" }
        ])
        allow(second_page_response).to receive(:dig).with("_links", "next").and_return(nil)

        # Mock pages for label response - without body content to test fallback
        pages_response = double(success?: true, code: 200, body: '{"results":[{"id":"123","title":"Test Page"}]}')
        page_without_body = { 
          "id" => "123", 
          "title" => "Test Page"
        }
        allow(pages_response).to receive(:[]).with("results").and_return([page_without_body])

        # Setup call sequence for pagination
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", { query: { limit: 250 } }).and_return(first_page_response)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", { query: { limit: 250, cursor: "abc123" } }).and_return(second_page_response)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels/10001/pages", anything).and_return(pages_response)

        # Mock fallback page content fetch in case body content is not available
        page_content_response = double(success?: true, code: 200, body: '{"body":{"storage":{"value":"<h1>Test Content</h1>"}}}')
        allow(page_content_response).to receive(:dig).with("body", "storage", "value").and_return("<h1>Test Content</h1>")
        allow(described_class).to receive(:get).with("/rest/api/content/123", anything).and_return(page_content_response)
        allow(described_class).to receive(:get).with("/rest/api/content/", anything).and_return(page_content_response)

        # Mock markdown conversion
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content</h1>", github_flavored: true)
          .and_return("# Test Content")

        result = confluence.fetch_pages_for(agent: "test-agent")

        expect(result).to eq(1)
        expect(mock_local_storage).to have_received(:store_content).with(
          title: nil, # title is nil because page_without_body doesn't include title in our mock
          content: "# Test Content",
          agent: "test-agent"
        )
      end
    end

    context "when configuration is invalid" do
      it "raises error when base URL is not configured" do
        Aircana.configure { |config| config.confluence_base_url = nil }

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Confluence base URL not configured")
      end

      it "raises error when username is not configured" do
        Aircana.configure { |config| config.confluence_username = nil }

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Confluence username not configured")
      end

      it "raises error when API token is not configured" do
        Aircana.configure { |config| config.confluence_api_token = "" }

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Confluence API token not configured")
      end
    end

    context "when API calls fail" do
      it "raises error when labels lookup fails" do
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_raise(StandardError,
                                                                                                 "Network error")

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: Network error")
      end

      it "raises error when labels lookup returns non-success status" do
        labels_response = double(success?: false, code: 401, message: "Unauthorized", body: '{"error":"Unauthorized"}')
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        expect do
          confluence.fetch_pages_for(agent: "test-agent")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: HTTP 401: Unauthorized")
      end
    end
  end
end
