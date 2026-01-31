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

    mock_llm_client = instance_double(Aircana::LLM::ClaudeClient)
    allow(Aircana::LLM).to receive(:client).and_return(mock_llm_client)
    allow(mock_llm_client).to receive(:prompt).and_return("Generated summary from LLM")
  end

  describe "#fetch_pages_for" do
    context "when configuration is valid" do
      it "fetches pages with matching label and stores them as markdown" do
        # Mock labels response
        labels_response = double(success?: true, code: 200,
                                 body: '{"results":[{"id":"10001","name":"test-kb","prefix":"global"}]}')
        allow(labels_response).to receive(:[]).with("results").and_return([
                                                                            { "id" => "10001", "name" => "test-kb",
                                                                              "prefix" => "global" }
                                                                          ])
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        # Mock pages for label response
        pages_response = double(success?: true, code: 200,
                                body: '{"results":[{"id":"123","title":"Test Page 1"},' \
                                      '{"id":"456","title":"Test Page 2"}]}')
        allow(pages_response).to receive(:[]).with("results").and_return([
                                                                           {
                                                                             "id" => "123",
                                                                             "title" => "Test Page 1",
                                                                             "body" => { "storage" => {
                                                                               "value" => "<h1>Test Content 1</h1>" \
                                                                                          "<p>Some content</p>"
                                                                             } }
                                                                           },
                                                                           {
                                                                             "id" => "456",
                                                                             "title" => "Test Page 2",
                                                                             "body" => { "storage" => {
                                                                               "value" => "<h1>Test Content 2</h1>" \
                                                                                          "<p>More content</p>"
                                                                             } }
                                                                           }
                                                                         ])
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels/10001/pages",
                                                     anything).and_return(pages_response)

        # Mock markdown conversion
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content 1</h1><p>Some content</p>", github_flavored: true)
          .and_return("# Test Content 1\n\nSome content")
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content 2</h1><p>More content</p>", github_flavored: true)
          .and_return("# Test Content 2\n\nMore content")

        result = confluence.fetch_pages_for(kb_name: "test-kb")

        expect(result[:pages_count]).to eq(2)
        expect(result[:sources]).to be_an(Array)
        expect(result[:sources].first["type"]).to eq("confluence")
        expect(mock_local_storage).to have_received(:store_content).with(
          title: "Test Page 1",
          content: "# Test Content 1\n\nSome content",
          kb_name: "test-kb"
        )
        expect(mock_local_storage).to have_received(:store_content).with(
          title: "Test Page 2",
          content: "# Test Content 2\n\nMore content",
          kb_name: "test-kb"
        )
      end

      it "returns 0 when no pages are found" do
        labels_response = double(success?: true, code: 200, body: '{"results":[]}')
        allow(labels_response).to receive(:[]).with("results").and_return([])
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        result = confluence.fetch_pages_for(kb_name: "nonexistent-kb")

        expect(result[:pages_count]).to eq(0)
        expect(result[:sources]).to eq([])
        expect(mock_local_storage).not_to have_received(:store_content)
      end

      it "handles pagination when label is found on second page" do
        # Mock first page response (no matching label)
        first_page_response = double(success?: true, code: 200,
                                     body: '{"results":[{"id":"10000","name":"other-label","prefix":"global"}]}')
        allow(first_page_response).to receive(:[]).with("results").and_return([
                                                                                { "id" => "10000",
                                                                                  "name" => "other-label",
                                                                                  "prefix" => "global" }
                                                                              ])
        allow(first_page_response).to receive(:dig).with("_links", "next").and_return("https://test.atlassian.net/wiki/api/v2/labels?cursor=abc123")

        # Mock second page response (with matching label)
        second_page_response = double(success?: true, code: 200,
                                      body: '{"results":[{"id":"10001","name":"test-kb","prefix":"global"}]}')
        allow(second_page_response).to receive(:[]).with("results").and_return([
                                                                                 { "id" => "10001",
                                                                                   "name" => "test-kb",
                                                                                   "prefix" => "global" }
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
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels",
                                                     { query: { limit: 250,
                                                                prefix: "global" } }).and_return(first_page_response)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels",
                                                     { query: { limit: 250, prefix: "global",
                                                                cursor: "abc123" } }).and_return(second_page_response)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels/10001/pages",
                                                     anything).and_return(pages_response)

        # Mock fallback page content fetch in case body content is not available
        page_content_response = double(success?: true, code: 200,
                                       body: '{"body":{"storage":{"value":"<h1>Test Content</h1>"}}}')
        allow(page_content_response).to receive(:dig).with("body", "storage",
                                                           "value").and_return("<h1>Test Content</h1>")
        allow(described_class).to receive(:get).with("/rest/api/content/123",
                                                     anything).and_return(page_content_response)
        allow(described_class).to receive(:get).with("/rest/api/content/", anything).and_return(page_content_response)

        # Mock markdown conversion
        allow(ReverseMarkdown).to receive(:convert)
          .with("<h1>Test Content</h1>", github_flavored: true)
          .and_return("# Test Content")

        result = confluence.fetch_pages_for(kb_name: "test-kb")

        expect(result[:pages_count]).to eq(1)
        expect(result[:sources]).to be_an(Array)
        expect(mock_local_storage).to have_received(:store_content).with(
          title: "Test Page",
          content: "# Test Content",
          kb_name: "test-kb"
        )
      end
    end

    context "when configuration is invalid" do
      it "raises error when base URL is not configured" do
        Aircana.configure { |config| config.confluence_base_url = nil }

        expect do
          confluence.fetch_pages_for(kb_name: "test-kb")
        end.to raise_error(Aircana::Error, "Confluence base URL not configured")
      end

      it "raises error when username is not configured" do
        Aircana.configure { |config| config.confluence_username = nil }

        expect do
          confluence.fetch_pages_for(kb_name: "test-kb")
        end.to raise_error(Aircana::Error, "Confluence username not configured")
      end

      it "raises error when API token is not configured" do
        Aircana.configure { |config| config.confluence_api_token = "" }

        expect do
          confluence.fetch_pages_for(kb_name: "test-kb")
        end.to raise_error(Aircana::Error, "Confluence API token not configured")
      end
    end

    context "when API calls fail" do
      it "raises error when labels lookup fails" do
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_raise(StandardError,
                                                                                                "Network error")

        expect do
          confluence.fetch_pages_for(kb_name: "test-kb")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: Network error")
      end

      it "raises error when labels lookup returns non-success status" do
        labels_response = double(success?: false, code: 401, message: "Unauthorized", body: '{"error":"Unauthorized"}')
        allow(labels_response).to receive(:dig).with("_links", "next").and_return(nil)
        allow(described_class).to receive(:get).with("/wiki/api/v2/labels", anything).and_return(labels_response)

        expect do
          confluence.fetch_pages_for(kb_name: "test-kb")
        end.to raise_error(Aircana::Error, "Failed to fetch pages from Confluence: HTTP 401: Unauthorized")
      end
    end
  end

  describe "#preprocess_confluence_macros" do
    it "converts code blocks with language parameter to pre/code tags" do
      html = <<~HTML
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:parameter ac:name="language">ruby</ac:parameter>
          <ac:plain-text-body><![CDATA[def hello
          puts "Hello, World!"
        end]]></ac:plain-text-body>
        </ac:structured-macro>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-ruby">')
      expect(result).to include("def hello")
      expect(result).to include('puts "Hello, World!"')
      expect(result).to include("</code></pre>")
    end

    it "converts code blocks without language parameter" do
      html = <<~HTML
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:plain-text-body><![CDATA[some plain text code]]></ac:plain-text-body>
        </ac:structured-macro>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-">')
      expect(result).to include("some plain text code")
    end

    it "handles code blocks with extra parameters" do
      html = <<~HTML
        <ac:structured-macro ac:name="code" ac:schema-version="1" ac:local-id="abc123" ac:macro-id="def456">
          <ac:parameter ac:name="language">javascript</ac:parameter>
          <ac:parameter ac:name="breakoutMode">wide</ac:parameter>
          <ac:parameter ac:name="breakoutWidth">760</ac:parameter>
          <ac:plain-text-body><![CDATA[console.log("test");]]></ac:plain-text-body>
        </ac:structured-macro>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-javascript">')
      expect(result).to include('console.log("test");')
      expect(result).not_to include("breakoutMode")
      expect(result).not_to include("760")
    end

    it "handles multiline code content" do
      html = <<~HTML
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:parameter ac:name="language">python</ac:parameter>
          <ac:plain-text-body><![CDATA[def greet(name):
            print(f"Hello, {name}!")

        if __name__ == "__main__":
            greet("World")]]></ac:plain-text-body>
        </ac:structured-macro>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-python">')
      expect(result).to include("def greet(name):")
      expect(result).to include('print(f"Hello, {name}!")')
      expect(result).to include('greet("World")')
    end

    it "removes empty code blocks" do
      html = <<~HTML
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:plain-text-body>   </ac:plain-text-body>
        </ac:structured-macro>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result.strip).to eq("")
    end

    it "processes multiple code blocks in the same document" do
      html = <<~HTML
        <p>First paragraph</p>
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:parameter ac:name="language">ruby</ac:parameter>
          <ac:plain-text-body><![CDATA[puts "first"]]></ac:plain-text-body>
        </ac:structured-macro>
        <p>Middle paragraph</p>
        <ac:structured-macro ac:name="code" ac:schema-version="1">
          <ac:parameter ac:name="language">python</ac:parameter>
          <ac:plain-text-body><![CDATA[print("second")]]></ac:plain-text-body>
        </ac:structured-macro>
        <p>Last paragraph</p>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-ruby">')
      expect(result).to include('puts "first"')
      expect(result).to include('<pre><code class="language-python">')
      expect(result).to include('print("second")')
      expect(result).to include("<p>First paragraph</p>")
      expect(result).to include("<p>Middle paragraph</p>")
      expect(result).to include("<p>Last paragraph</p>")
    end

    it "handles code blocks with whitespace around CDATA" do
      html = <<~HTML
        <p>Before code block</p>
        <ac:structured-macro ac:name="code" ac:schema-version="1"
              ac:macro-id="f3ae4329-9f50-48c9-98a8-a99b35d04cc6"><ac:plain-text-body>
                <![CDATA[execute("CREATE VIEW...")]]>
              </ac:plain-text-body></ac:structured-macro>
        <p>After code block</p>
      HTML

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-">')
      expect(result).to include('execute("CREATE VIEW...")')
      expect(result).to include("<p>Before code block</p>")
      expect(result).to include("<p>After code block</p>")
    end

    it "handles inline code blocks without whitespace followed by info macros" do
      html = "<p>Before code</p>" \
             '<ac:structured-macro ac:name="code" ac:schema-version="1" ac:macro-id="abc123">' \
             '<ac:plain-text-body><![CDATA[execute("CREATE VIEW")]]></ac:plain-text-body>' \
             "</ac:structured-macro>" \
             "<p>Middle content</p>" \
             '<ac:structured-macro ac:name="info" ac:schema-version="1">' \
             "<ac:rich-text-body><p>Important info here</p></ac:rich-text-body>" \
             "</ac:structured-macro>" \
             "<p>After info</p>"

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-">')
      expect(result).to include('execute("CREATE VIEW")')
      expect(result).to include("<p>Before code</p>")
      expect(result).to include("<p>Middle content</p>")
      expect(result).to include("<p>Important info here</p>")
      expect(result).to include("<p>After info</p>")
    end

    it "handles code blocks with non-language parameters only" do
      html = '<ac:structured-macro ac:name="code" ac:schema-version="1">' \
             '<ac:parameter ac:name="breakoutMode">wide</ac:parameter>' \
             "<ac:plain-text-body><![CDATA[some code here]]></ac:plain-text-body>" \
             "</ac:structured-macro>" \
             "<p>Content after</p>"

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include('<pre><code class="language-">')
      expect(result).to include("some code here")
      expect(result).to include("<p>Content after</p>")
    end

    it "handles multiple code blocks where later one has language but earlier one does not" do
      html = "<p>Before first code block</p>" \
             '<ac:structured-macro ac:name="code" ac:schema-version="1" ac:macro-id="first">' \
             "<ac:plain-text-body><![CDATA[first code block - no language]]></ac:plain-text-body>" \
             "</ac:structured-macro>" \
             "<p>Content between code blocks - THIS MUST BE PRESERVED</p>" \
             '<ac:structured-macro ac:name="code" ac:schema-version="1" ac:macro-id="second">' \
             '<ac:parameter ac:name="language">ruby</ac:parameter>' \
             "<ac:plain-text-body><![CDATA[second code block - with language]]></ac:plain-text-body>" \
             "</ac:structured-macro>" \
             "<p>After second code block</p>"

      result = confluence.send(:preprocess_confluence_macros, html)

      expect(result).to include("first code block - no language")
      expect(result).to include("second code block - with language")
      expect(result).to include("Content between code blocks - THIS MUST BE PRESERVED")
      expect(result).to include("After second code block")
    end
  end

  describe "checksum optimization" do
    let(:mock_llm_client) { instance_double(Aircana::LLM::ClaudeClient) }
    let(:page_content) { "<h1>Test Content</h1><p>Some content here</p>" }
    let(:markdown_content) { "# Test Content\n\nSome content here" }

    before do
      allow(Aircana::LLM).to receive(:client).and_return(mock_llm_client)
      allow(ReverseMarkdown).to receive(:convert)
        .with(page_content, github_flavored: true)
        .and_return(markdown_content)
    end

    describe "#extract_page_metadata" do
      it "includes content_checksum in returned metadata" do
        page = {
          "id" => "123",
          "title" => "Test Page",
          "body" => { "storage" => { "value" => page_content } }
        }
        allow(mock_llm_client).to receive(:prompt).and_return("Generated summary")

        metadata = confluence.send(:extract_page_metadata, page, "test-kb")

        expect(metadata["content_checksum"]).to start_with("sha256:")
        expect(metadata["summary"]).to eq("Generated summary")
      end

      it "reuses summary when checksum matches existing metadata" do
        checksum = Aircana::Checksum.compute(markdown_content)
        existing_metadata = {
          "123" => {
            "id" => "123",
            "title" => "Test Page",
            "summary" => "Existing cached summary",
            "content_checksum" => checksum
          }
        }
        page = {
          "id" => "123",
          "title" => "Test Page",
          "body" => { "storage" => { "value" => page_content } }
        }
        allow(mock_llm_client).to receive(:prompt)

        metadata = confluence.send(:extract_page_metadata, page, "test-kb", existing_metadata: existing_metadata)

        expect(metadata["summary"]).to eq("Existing cached summary")
        expect(metadata["content_checksum"]).to eq(checksum)
        expect(mock_llm_client).not_to have_received(:prompt)
      end

      it "generates new summary when checksum differs" do
        existing_metadata = {
          "123" => {
            "id" => "123",
            "title" => "Test Page",
            "summary" => "Old summary",
            "content_checksum" => "sha256:different_checksum"
          }
        }
        page = {
          "id" => "123",
          "title" => "Test Page",
          "body" => { "storage" => { "value" => page_content } }
        }
        allow(mock_llm_client).to receive(:prompt).and_return("New generated summary")

        metadata = confluence.send(:extract_page_metadata, page, "test-kb", existing_metadata: existing_metadata)

        expect(metadata["summary"]).to eq("New generated summary")
        expect(mock_llm_client).to have_received(:prompt)
      end

      it "generates new summary when existing metadata has no checksum" do
        existing_metadata = {
          "123" => {
            "id" => "123",
            "title" => "Test Page",
            "summary" => "Old summary without checksum"
          }
        }
        page = {
          "id" => "123",
          "title" => "Test Page",
          "body" => { "storage" => { "value" => page_content } }
        }
        allow(mock_llm_client).to receive(:prompt).and_return("New generated summary")

        metadata = confluence.send(:extract_page_metadata, page, "test-kb", existing_metadata: existing_metadata)

        expect(metadata["summary"]).to eq("New generated summary")
        expect(mock_llm_client).to have_received(:prompt)
      end
    end

    describe "#load_existing_page_metadata" do
      it "loads page metadata keyed by page ID" do
        sources = [
          {
            "type" => "confluence",
            "pages" => [
              { "id" => "123", "title" => "Page 1", "summary" => "Summary 1", "content_checksum" => "sha256:abc" },
              { "id" => "456", "title" => "Page 2", "summary" => "Summary 2", "content_checksum" => "sha256:def" }
            ]
          }
        ]
        allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest).with("test-kb").and_return(sources)

        metadata = confluence.send(:load_existing_page_metadata, "test-kb")

        expect(metadata["123"]["title"]).to eq("Page 1")
        expect(metadata["456"]["title"]).to eq("Page 2")
      end

      it "returns empty hash when no confluence sources exist" do
        sources = [{ "type" => "web", "urls" => [] }]
        allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest).with("test-kb").and_return(sources)

        metadata = confluence.send(:load_existing_page_metadata, "test-kb")

        expect(metadata).to eq({})
      end
    end
  end
end
