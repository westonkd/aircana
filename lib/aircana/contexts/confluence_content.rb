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

        ReverseMarkdown.convert(html_content, github_flavored: true)
      end

      def log_pages_found(count, kb_name)
        Aircana.human_logger.info "Found #{count} pages for KB '#{kb_name}'"
      end

      def store_page_as_markdown(page, kb_name, kb_type = "local")
        content = page&.dig("body", "storage", "value") || fetch_page_content(page&.[]("id"))
        markdown_content = convert_to_markdown(content)

        @local_storage.store_content(
          title: page&.[]("title"),
          content: markdown_content,
          kb_name: kb_name,
          kb_type: kb_type
        )
      end
    end
  end
end
