# frozen_string_literal: true

module Aircana
  module Contexts
    module ConfluenceContent
      def fetch_page_content(page_id)
        Aircana.human_logger.info("Looking for page with ID `#{page_id}`")
        response = get_page_content(page_id)
        response.dig("body", "storage", "value") || ""
      rescue HTTParty::Error, StandardError => e
        handle_api_error("fetch content for page #{page_id}", e, "Failed to fetch page content")
      end

      def convert_to_markdown(html_content)
        return "" if html_content.nil? || html_content.empty?

        # Preprocess Confluence macros before converting to Markdown
        cleaned_html = preprocess_confluence_macros(html_content)
        ReverseMarkdown.convert(cleaned_html, github_flavored: true)
      end

      # rubocop:disable Layout/LineLength, Metrics/MethodLength
      def preprocess_confluence_macros(html)
        # Process Confluence structured macros to make them compatible with Markdown conversion
        cleaned = html.dup

        # Convert code blocks with CDATA content to <pre><code> tags
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="code"[^>]*>(?:.*?<ac:parameter[^>]*ac:name="language"[^>]*>([^<]*)</ac:parameter>)?.*?<ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>.*?</ac:structured-macro>}m
        ) do
          language = Regexp.last_match(1)&.strip || ""
          code = Regexp.last_match(2) || ""
          "<pre><code class=\"language-#{language}\">#{code}</code></pre>"
        end

        # Remove empty code blocks (common issue with Confluence API)
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="code"[^>]*>.*?<ac:plain-text-body>\s*</ac:plain-text-body>.*?</ac:structured-macro>}m, ""
        )

        # Convert panel macros to blockquotes, preserving inner content
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="panel"[^>]*>.*?<ac:rich-text-body>(.*?)</ac:rich-text-body>.*?</ac:structured-macro>}m, '<blockquote>\1</blockquote>'
        )

        # Convert info/note/warning macros to blockquotes with indicators
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="info"[^>]*>.*?<ac:rich-text-body>(.*?)</ac:rich-text-body>.*?</ac:structured-macro>}m, '<blockquote><strong>ℹ️ Info:</strong> \1</blockquote>'
        )
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="note"[^>]*>.*?<ac:rich-text-body>(.*?)</ac:rich-text-body>.*?</ac:structured-macro>}m, '<blockquote><strong>📝 Note:</strong> \1</blockquote>'
        )
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*ac:name="warning"[^>]*>.*?<ac:rich-text-body>(.*?)</ac:rich-text-body>.*?</ac:structured-macro>}m, '<blockquote><strong>⚠️ Warning:</strong> \1</blockquote>'
        )

        # Strip other structured macros but preserve rich text body content
        cleaned.gsub!(
          %r{<ac:structured-macro[^>]*>.*?<ac:rich-text-body>(.*?)</ac:rich-text-body>.*?</ac:structured-macro>}m, '\1'
        )

        # Remove any remaining Confluence-specific tags
        cleaned.gsub!(%r{</?ac:[^>]*>}m, "")

        # Clean up Confluence parameter tags
        cleaned.gsub!(%r{<ac:parameter[^>]*>.*?</ac:parameter>}m, "")

        cleaned
      end
      # rubocop:enable Layout/LineLength, Metrics/MethodLength

      def log_pages_found(count, kb_name)
        Aircana.human_logger.info "Found #{count} pages for KB '#{kb_name}'"
      end

      def store_page_as_markdown(page, kb_name)
        content = page&.dig("body", "storage", "value") || fetch_page_content(page&.[]("id"))
        markdown_content = convert_to_markdown(content)

        @local_storage.store_content(
          title: page&.[]("title"),
          content: markdown_content,
          kb_name: kb_name
        )
      end
    end
  end
end
