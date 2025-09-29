# frozen_string_literal: true

require "httparty"
require "reverse_markdown"
require "uri"
require_relative "local"
require_relative "manifest"
require_relative "../progress_tracker"
require_relative "../version"
require_relative "../llm/claude_client"

module Aircana
  module Contexts
    class Web # rubocop:disable Metrics/ClassLength
      include HTTParty

      headers "User-Agent" => "Aircana/#{Aircana::VERSION} (+https://github.com/westonkd/aircana)"
      default_timeout 30
      follow_redirects true

      def initialize
        @local_storage = Local.new
      end

      def fetch_url_for(agent:, url:)
        validate_url!(url)

        page_data = fetch_and_process_url(url)
        store_page_as_markdown(page_data, agent)

        build_url_metadata(page_data)
      rescue StandardError => e
        handle_fetch_error(url, e)
        nil
      end

      def fetch_urls_for(agent:, urls:) # rubocop:disable Metrics/MethodLength
        return { pages_count: 0, sources: [] } if urls.empty?

        pages_metadata = []
        successful_urls = []

        ProgressTracker.with_batch_progress(urls, "Fetching URLs") do |url, _index|
          metadata = fetch_url_for(agent: agent, url: url)
          if metadata
            pages_metadata << metadata
            successful_urls << url
          end
        end

        if successful_urls.any?
          sources = build_sources_metadata(successful_urls, pages_metadata)
          update_or_create_manifest(agent, sources)
          { pages_count: successful_urls.size, sources: sources }
        else
          { pages_count: 0, sources: [] }
        end
      end

      def refresh_web_sources(agent:) # rubocop:disable Metrics/CyclomaticComplexity
        sources = Manifest.sources_from_manifest(agent)
        web_sources = sources.select { |s| s["type"] == "web" }

        return { pages_count: 0, sources: [] } if web_sources.empty?

        all_urls = web_sources.flat_map { |source| source["urls"]&.map { |u| u["url"] } || [] }
        return { pages_count: 0, sources: [] } if all_urls.empty?

        fetch_urls_for(agent: agent, urls: all_urls)
      end

      private

      def validate_url!(url)
        uri = URI.parse(url)
        raise Error, "URL must use HTTP or HTTPS protocol" unless %w[http https].include?(uri.scheme)
        raise Error, "Invalid URL format" unless uri.host
      rescue URI::InvalidURIError
        raise Error, "Invalid URL format"
      end

      def fetch_and_process_url(url) # rubocop:disable Metrics/MethodLength
        Aircana.human_logger.info("Fetching #{url}")

        response = self.class.get(url)

        raise Error, "Failed to fetch URL (#{response.code})" unless response.success?

        html_title = extract_title(response.body)
        content = convert_to_markdown(response.body)
        title = generate_meaningful_title(html_title, content, url)

        {
          url: url,
          title: title,
          content: content,
          last_fetched: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
      end

      def extract_title(html) # rubocop:disable Metrics/MethodLength
        title_match = html.match(%r{<title[^>]*>(.*?)</title>}im)
        return nil unless title_match

        title = title_match[1].strip
        # Decode HTML entities
        title.gsub(/&([a-zA-Z]+|#\d+);/) do |match|
          case match
          when "&amp;" then "&"
          when "&lt;" then "<"
          when "&gt;" then ">"
          when "&quot;" then '"'
          when "&#39;", "&apos;" then "'"
          else match
          end
        end
      end

      def extract_title_from_url(url)
        uri = URI.parse(url)
        # Use the last path segment or host as fallback title
        path_segments = uri.path.split("/").reject(&:empty?)
        if path_segments.any?
          path_segments.last.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
        else
          uri.host
        end
      end

      def generate_meaningful_title(html_title, content, url) # rubocop:disable Metrics/CyclomaticComplexity
        # If we have a good HTML title that's descriptive, use it
        return html_title if html_title && html_title.length > 10 && !generic_title?(html_title)

        # If content is too short, use fallback
        return html_title || extract_title_from_url(url) if content.length < 50

        # Use Claude to generate a meaningful title based on content
        begin
          generate_title_with_claude(content, url)
        rescue StandardError => e
          Aircana.human_logger.warn("Failed to generate title with Claude: #{e.message}")
          html_title || extract_title_from_url(url)
        end
      end

      def generic_title?(title)
        generic_patterns = [
          /^(home|index|welcome|untitled|document)$/i,
          /^(page|default)$/i,
          /^\s*$/,
          # Truncated titles (contain ellipsis)
          /\.\.\./,
          # Titles with excessive metadata (site names, IDs, etc.)
          / - .+ - \d+$/,
          # Question titles that are truncated
          /^how do i .+\.\.\./i,
          /^what is .+\.\.\./i
        ]

        generic_patterns.any? { |pattern| title.match?(pattern) }
      end

      def generate_title_with_claude(content, url)
        prompt = build_title_generation_prompt(content, url)
        claude_client = LLM::ClaudeClient.new
        claude_client.prompt(prompt).strip
      end

      def build_title_generation_prompt(content, url) # rubocop:disable Metrics/MethodLength
        # Truncate content to avoid overly long prompts
        truncated_content = content.length > 1000 ? "#{content[0..1000]}..." : content

        <<~PROMPT
          Based on the following web page content from #{url}, generate a concise, descriptive title
          that would help an AI agent understand what this document contains and when it would be useful.

          The title should be:
          - 3-8 words long
          - Focused on the main topic or purpose
          - Helpful for knowledge retrieval
          - Professional and clear

          Content:
          #{truncated_content}

          Respond with only the title, no additional text or explanation.
        PROMPT
      end

      def convert_to_markdown(html)
        return "" if html.nil? || html.empty?

        # Extract meaningful content by removing unwanted elements
        cleaned_html = extract_main_content(html)

        ReverseMarkdown.convert(cleaned_html, github_flavored: true)
      rescue StandardError => e
        Aircana.human_logger.warn "Failed to convert HTML to markdown: #{e.message}"
        # Fallback to plain text extraction
        extract_text_content(html)
      end

      def store_page_as_markdown(page_data, agent)
        @local_storage.store_content(
          title: page_data[:title],
          content: page_data[:content],
          agent: agent
        )
      end

      def build_url_metadata(page_data)
        {
          "url" => page_data[:url]
        }
      end

      def build_sources_metadata(_urls, pages_metadata)
        [
          {
            "type" => "web",
            "urls" => pages_metadata
          }
        ]
      end

      def update_or_create_manifest(agent, new_sources)
        existing_sources = Manifest.sources_from_manifest(agent)

        # Remove existing web sources and add new ones
        other_sources = existing_sources.reject { |s| s["type"] == "web" }
        all_sources = other_sources + new_sources

        if Manifest.manifest_exists?(agent)
          Manifest.update_manifest(agent, all_sources)
        else
          Manifest.create_manifest(agent, all_sources)
        end
      end

      def handle_fetch_error(url, error)
        case error
        when URI::InvalidURIError
          Aircana.human_logger.error "Invalid URL format: #{url}"
        when HTTParty::Error
          Aircana.human_logger.error "HTTP error fetching #{url}: #{error.message}"
        when Error
          Aircana.human_logger.error "Error fetching #{url}: #{error.message}"
        else
          Aircana.human_logger.error "Unexpected error fetching #{url}: #{error.message}"
        end
      end

      def extract_main_content(html) # rubocop:disable Metrics/MethodLength
        # Try to find the main content area using common selectors
        content_patterns = [
          # Common main content selectors
          %r{<main[^>]*>(.*?)</main>}mi,
          %r{<article[^>]*>(.*?)</article>}mi,
          %r{<div[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</div>}mi,
          %r{<div[^>]*id="content"[^>]*>(.*?)</div>}mi,
          %r{<div[^>]*class="[^"]*post[^"]*"[^>]*>(.*?)</div>}mi,
          # Documentation specific
          %r{<div[^>]*class="[^"]*docs[^"]*"[^>]*>(.*?)</div>}mi,
          %r{<div[^>]*class="[^"]*documentation[^"]*"[^>]*>(.*?)</div>}mi,
          # Body content as fallback
          %r{<body[^>]*>(.*?)</body>}mi
        ]

        extracted_content = nil
        content_patterns.each do |pattern|
          match = html.match(pattern)
          if match && match[1].strip.length > 100 # Ensure meaningful content
            extracted_content = match[1]
            break
          end
        end

        # If no pattern matched or content is too short, use the full HTML
        content_to_clean = extracted_content || html

        # Remove unwanted elements
        clean_html_content(content_to_clean)
      end

      def clean_html_content(html) # rubocop:disable Metrics/MethodLength
        cleaned = html.dup

        # Remove script and style tags completely
        cleaned = cleaned.gsub(%r{<script[^>]*>.*?</script>}mi, "")
        cleaned = cleaned.gsub(%r{<style[^>]*>.*?</style>}mi, "")

        # Remove navigation, header, footer, sidebar elements
        navigation_selectors = %w[nav header footer aside sidebar menu breadcrumb]
        navigation_selectors.each do |selector|
          # Remove by tag name
          cleaned = cleaned.gsub(%r{<#{selector}[^>]*>.*?</#{selector}>}mi, "")
          # Remove by class name (common patterns)
          cleaned = cleaned.gsub(%r{<[^>]+class="[^"]*#{selector}[^"]*"[^>]*>.*?</[^>]+>}mi, "")
          cleaned = cleaned.gsub(%r{<[^>]+id="#{selector}"[^>]*>.*?</[^>]+>}mi, "")
        end

        # Remove common non-content elements
        unwanted_patterns = [
          %r{<div[^>]*class="[^"]*comment[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*social[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*share[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*ad[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*advertisement[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*popup[^"]*"[^>]*>.*?</div>}mi,
          %r{<div[^>]*class="[^"]*modal[^"]*"[^>]*>.*?</div>}mi
        ]

        unwanted_patterns.each do |pattern|
          cleaned = cleaned.gsub(pattern, "")
        end

        # Clean up whitespace
        cleaned.gsub(/\n\s*\n\s*\n+/, "\n\n").strip
      end

      def extract_text_content(html) # rubocop:disable Metrics/MethodLength
        # Fallback method for plain text extraction
        text = html.gsub(%r{<script[^>]*>.*?</script>}mi, "")
                   .gsub(%r{<style[^>]*>.*?</style>}mi, "")
                   .gsub(/<[^>]+>/, "")
                   .gsub("&nbsp;", " ")
                   .gsub("&amp;", "&")
                   .gsub("&lt;", "<")
                   .gsub("&gt;", ">")
                   .gsub("&quot;", '"')
                   .gsub(/\s+/, " ")
                   .strip

        # If the extracted text is very short, it might not be useful
        text.length < 20 ? "Content could not be extracted from this page." : text
      end
    end
  end
end
