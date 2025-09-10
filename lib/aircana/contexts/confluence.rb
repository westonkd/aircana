# frozen_string_literal: true

require "httparty"
require "reverse_markdown"
require_relative "local"

module Aircana
  module Contexts
    class Confluence
      include HTTParty

      def initialize
        @local_storage = Local.new
      end

      def fetch_pages_for(agent:)
        validate_configuration!
        setup_httparty

        pages = ProgressTracker.with_spinner("Searching for pages labeled '#{agent}'") do
          fetch_pages_by_label(agent)
        end

        log_pages_found(pages.size, agent)

        return 0 if pages.empty?

        ProgressTracker.with_batch_progress(pages, "Processing pages") do |page, _index|
          store_page_as_markdown(page, agent)
        end

        pages.size
      end

      private

      def validate_configuration!
        config = Aircana.configuration

        if config.confluence_base_url.nil? || config.confluence_base_url.empty?
          raise Error,
                "Confluence base URL not configured"
        end
        return unless config.confluence_api_token.nil? || config.confluence_api_token.empty?

        raise Error,
              "Confluence API token not configured"
      end

      def setup_httparty
        config = Aircana.configuration

        self.class.base_uri config.confluence_base_url
        self.class.headers "Authorization" => "Bearer #{config.confluence_api_token}"
        self.class.headers "Content-Type" => "application/json"
      end

      def fetch_pages_by_label(agent)
        cql = "label = \"#{agent}\""
        response = search_pages(cql)
        response["results"] || []
      rescue HTTParty::Error, StandardError => e
        handle_api_error("search pages for agent '#{agent}'", e, "Failed to fetch pages from Confluence")
      end

      def fetch_page_content(page_id)
        response = get_page_content(page_id)
        response.dig("body", "storage", "value") || ""
      rescue HTTParty::Error, StandardError => e
        handle_api_error("fetch content for page #{page_id}", e, "Failed to fetch page content")
      end

      def convert_to_markdown(html_content)
        return "" if html_content.nil? || html_content.empty?

        ReverseMarkdown.convert(html_content, github_flavored: true)
      end

      def search_pages(cql)
        response = self.class.get("/rest/api/search", {
                                    query: {
                                      cql: cql,
                                      limit: 100
                                    }
                                  })
        validate_response(response)
        response
      end

      def get_page_content(page_id)
        response = self.class.get("/rest/api/content/#{page_id}", {
                                    query: {
                                      expand: "body.storage"
                                    }
                                  })
        validate_response(response)
        response
      end

      def validate_response(response)
        return if response.success?

        raise Error, "HTTP #{response.code}: #{response.message}"
      end

      def handle_api_error(operation, error, message)
        Aircana.human_logger.error "Failed to #{operation}: #{error.message}"
        raise Error, "#{message}: #{error.message}"
      end

      def log_pages_found(count, agent)
        Aircana.human_logger.info "Found #{count} pages for agent '#{agent}'"
      end

      def store_page_as_markdown(page, agent)
        content = fetch_page_content(page["id"])
        markdown_content = convert_to_markdown(content)

        @local_storage.store_content(
          title: page["title"],
          content: markdown_content,
          agent: agent
        )
      end
    end
  end
end
