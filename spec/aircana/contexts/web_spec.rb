# frozen_string_literal: true

require "spec_helper"
require "aircana/contexts/web"

RSpec.describe Aircana::Contexts::Web do
  let(:web) { described_class.new }
  let(:kb_name) { "test-kb" }
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
      double(kb_knowledge_dir: "/tmp/test_kbs")
    )
    allow(Aircana).to receive(:human_logger).and_return(
      double(info: nil, success: nil, warn: nil, error: nil)
    )
  end

  describe "#fetch_urls_for" do
    it "handles empty URL list" do
      result = web.fetch_urls_for(kb_name: kb_name, urls: [])

      expect(result[:pages_count]).to eq(0)
      expect(result[:sources]).to eq([])
    end
  end

  describe "#refresh_web_sources" do
    it "returns empty result when no web sources exist" do
      allow(Aircana::Contexts::Manifest).to receive(:sources_from_manifest)
        .with(kb_name).and_return([])

      result = web.refresh_web_sources(kb_name: kb_name)

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

    describe "#generate_meaningful_title" do
      let(:url) { "https://example.com/test-page" }
      let(:mock_llm_client) { instance_double(Aircana::LLM::ClaudeClient) }

      before do
        allow(Aircana::LLM).to receive(:client).and_return(mock_llm_client)
      end

      it "uses HTML title when it's descriptive" do
        html_title = "Comprehensive Guide to Web Development"
        content = "Some content about web development..."

        title = web.send(:generate_meaningful_title, html_title, content, url)
        expect(title).to eq(html_title)
      end

      it "generates title with LLM when HTML title is generic" do
        html_title = "Home"
        content = "This page explains how to configure Docker containers for production deployment. " \
                  "It covers best practices for setting up production environments with proper logging, " \
                  "monitoring, and security configurations to ensure reliable deployments."
        generated_title = "Docker Production Configuration Guide"

        allow(mock_llm_client).to receive(:prompt).and_return(generated_title)

        title = web.send(:generate_meaningful_title, html_title, content, url)
        expect(title).to eq(generated_title)
        expect(mock_llm_client).to have_received(:prompt)
      end

      it "falls back to HTML title when LLM fails" do
        html_title = "Page Title"
        content = "Some content here that is long enough to trigger LLM generation. " \
                  "This content should be substantial enough to pass the minimum length requirement " \
                  "and attempt to generate a title with LLM, but it will fail in this test."

        allow(mock_llm_client).to receive(:prompt).and_raise(StandardError.new("LLM error"))

        title = web.send(:generate_meaningful_title, html_title, content, url)
        expect(title).to eq(html_title)
      end

      it "uses URL title when content is too short" do
        html_title = nil
        content = "Short"

        title = web.send(:generate_meaningful_title, html_title, content, url)
        expect(title).to eq("Test Page")
      end

      it "generates title with LLM when HTML title is nil" do
        html_title = nil
        content = "This is a detailed article about machine learning algorithms and their applications. " \
                  "The article covers supervised and unsupervised learning techniques, neural networks, " \
                  "and practical examples of implementing these algorithms in real-world scenarios."
        generated_title = "Machine Learning Algorithms Guide"

        allow(mock_llm_client).to receive(:prompt).and_return(generated_title)

        title = web.send(:generate_meaningful_title, html_title, content, url)
        expect(title).to eq(generated_title)
      end
    end

    describe "#generic_title?" do
      it "identifies generic titles" do
        expect(web.send(:generic_title?, "Home")).to be true
        expect(web.send(:generic_title?, "Index")).to be true
        expect(web.send(:generic_title?, "Welcome")).to be true
        expect(web.send(:generic_title?, "Untitled")).to be true
        expect(web.send(:generic_title?, "Page")).to be true
        expect(web.send(:generic_title?, "")).to be true
      end

      it "identifies truncated and metadata-heavy titles" do
        expect(web.send(:generic_title?, "How do I add a section to...")).to be true
        expect(web.send(:generic_title?, "Question Title - Site Name - 123")).to be true
        expect(web.send(:generic_title?, "What is the best way to...")).to be true
        expect(web.send(:generic_title?, "Article Title - Community - 688")).to be true
      end

      it "identifies descriptive titles" do
        expect(web.send(:generic_title?, "User Guide")).to be false
        expect(web.send(:generic_title?, "API Documentation")).to be false
        expect(web.send(:generic_title?, "Getting Started with React")).to be false
        expect(web.send(:generic_title?, "Docker Container Setup")).to be false
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
