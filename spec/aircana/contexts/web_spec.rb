# frozen_string_literal: true

require "spec_helper"
require "aircana/contexts/web"

RSpec.describe Aircana::Contexts::Web do
  let(:web) { described_class.new }
  let(:agent) { "test-agent" }
  let(:url) { "https://example.com/test-page" }
  let(:html_content) do
    <<~HTML
      <html>
        <head>
          <title>Test Page Title</title>
        </head>
        <body>
          <h1>Main Heading</h1>
          <p>This is some test content.</p>
          <a href="/link">Test Link</a>
        </body>
      </html>
    HTML
  end
  let(:expected_markdown) { "# Main Heading\n\nThis is some test content.\n\n[Test Link](/link)" }

  before do
    allow(Aircana).to receive(:configuration).and_return(
      double(agent_knowledge_dir: "/tmp/test_agents")
    )
    allow(Aircana).to receive(:human_logger).and_return(
      double(info: nil, success: nil, warn: nil, error: nil)
    )
  end

  describe "#fetch_urls_for" do
    it "handles empty URL list" do
      result = web.fetch_urls_for(agent: agent, urls: [])

      expect(result[:pages_count]).to eq(0)
      expect(result[:sources]).to eq([])
    end
  end

  describe "#refresh_web_sources" do
    it "returns empty result when no web sources exist" do
      allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest)
        .with(agent).and_return([])

      result = web.refresh_web_sources(agent: agent)

      expect(result[:pages_count]).to eq(0)
      expect(result[:sources]).to eq([])
    end
  end

  describe "private methods" do
    describe "#extract_title" do
      it "extracts title from HTML" do
        title = web.send(:extract_title, "<html><head><title>Test Title</title></head></html>")
        expect(title).to eq("Test Title")
      end

      it "handles HTML entities in titles" do
        title = web.send(:extract_title, "<html><head><title>Test &amp; Title</title></head></html>")
        expect(title).to eq("Test & Title")
      end

      it "returns nil when no title exists" do
        title = web.send(:extract_title, "<html><head></head></html>")
        expect(title).to be_nil
      end
    end

    describe "#extract_title_from_url" do
      it "extracts title from URL path" do
        title = web.send(:extract_title_from_url, "https://example.com/user-guide")
        expect(title).to eq("User Guide")
      end

      it "uses host when no path segments exist" do
        title = web.send(:extract_title_from_url, "https://example.com")
        expect(title).to eq("example.com")
      end
    end

    describe "#convert_to_markdown" do
      it "converts HTML to markdown" do
        markdown = web.send(:convert_to_markdown, "<h1>Title</h1><p>Content</p>")
        expect(markdown).to include("# Title")
        expect(markdown).to include("Content")
      end

      it "handles empty HTML" do
        markdown = web.send(:convert_to_markdown, "")
        expect(markdown).to eq("")
      end

      it "falls back to plain text on conversion errors" do
        allow(ReverseMarkdown).to receive(:convert).and_raise(StandardError.new("Conversion failed"))

        markdown = web.send(:convert_to_markdown,
                            "<h1>Title</h1><p>Content goes here with more text to ensure it's long enough</p>")
        expect(markdown).to include("Title")
        expect(markdown).to include("Content goes here")
      end
    end

    describe "#extract_main_content" do
      it "extracts content from main tag" do
        html = "<html><body><nav>Navigation</nav><main><h1>Main Content</h1>" \
               "<p>This is the main content.</p></main><footer>Footer</footer></body></html>"
        content = web.send(:extract_main_content, html)
        expect(content).to include("Main Content")
        expect(content).not_to include("Navigation")
        expect(content).not_to include("Footer")
      end

      it "extracts content from article tag" do
        html = "<html><body><article><h1>Article Title</h1>" \
               "<p>Article content here.</p></article><aside>Sidebar</aside></body></html>"
        content = web.send(:extract_main_content, html)
        expect(content).to include("Article Title")
        expect(content).not_to include("Sidebar")
      end

      it "removes unwanted elements" do
        html = "<div><script>alert('test');</script><style>.test { color: red; }</style>" \
               "<h1>Title</h1><p>Content</p></div>"
        content = web.send(:extract_main_content, html)
        expect(content).not_to include("alert('test')")
        expect(content).not_to include("color: red")
        expect(content).to include("Title")
        expect(content).to include("Content")
      end
    end

    describe "#extract_text_content" do
      it "extracts plain text from HTML" do
        html = "<h1>Title</h1><p>This is <strong>content</strong> with &amp; entities.</p>"
        text = web.send(:extract_text_content, html)
        expect(text).to eq("TitleThis is content with & entities.")
      end

      it "handles very short content" do
        html = "<p>Hi</p>"
        text = web.send(:extract_text_content, html)
        expect(text).to eq("Content could not be extracted from this page.")
      end
    end
  end
end
