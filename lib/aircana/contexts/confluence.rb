# frozen_string_literal: true

require "httparty"
require "reverse_markdown"
require_relative "local"

module Aircana
  module Contexts
    class Confluence
      include HTTParty

      LABEL_PREFIX = "global"

      def initialize
        @local_storage = Local.new
      end

      def fetch_pages_for(agent:)
        validate_configuration!
        setup_httparty

        pages = search_and_log_pages(agent)
        return 0 if pages.empty?

        process_pages(pages, agent)
        pages.size
      end

      def search_and_log_pages(agent)
        pages = ProgressTracker.with_spinner("Searching for pages labeled '#{agent}'") do
          fetch_pages_by_label(agent)
        end
        log_pages_found(pages.size, agent)
        pages
      end

      def process_pages(pages, agent)
        ProgressTracker.with_batch_progress(pages, "Processing pages") do |page, _index|
          store_page_as_markdown(page, agent)
        end
      end

      private

      def validate_configuration!
        config = Aircana.configuration

        if config.confluence_base_url.nil? || config.confluence_base_url.empty?
          raise Error,
                "Confluence base URL not configured"
        end

        if config.confluence_username.nil? || config.confluence_username.empty?
          raise Error,
                "Confluence username not configured"
        end

        return unless config.confluence_api_token.nil? || config.confluence_api_token.empty?

        raise Error,
              "Confluence API token not configured"
      end

      def setup_httparty
        config = Aircana.configuration

        self.class.base_uri config.confluence_base_url
        self.class.basic_auth config.confluence_username, config.confluence_api_token
        self.class.headers "Content-Type" => "application/json"
      end

      def fetch_pages_by_label(agent)
        label_id = find_label_id(agent)
        return [] if label_id.nil?

        response = get_pages_for_label(label_id)
        response["results"] || []
      rescue HTTParty::Error, StandardError => e
        handle_api_error("fetch pages for agent '#{agent}'", e, "Failed to fetch pages from Confluence")
      end

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

      def find_label_id(agent_name)
        path = "/wiki/api/v2/labels"
        query_params = { limit: 250, prefix: LABEL_PREFIX }
        page_number = 1

        loop do
          log_request("GET", path, query_params.merge("Page" => page_number), pagination: true)

          response = self.class.get(path, { query: query_params })
          log_response(response, "Labels lookup (page #{page_number})", pagination: true)
          validate_response(response)

          labels = response["results"] || []
          matching_label = labels.find { |label| label["name"] == agent_name }

          if matching_label
            # Clear the dynamic pagination line before returning
            print "\r\e[K"
            return matching_label["id"]
          end

          # Check for next page
          next_url = get_next_page_url(response)
          break unless next_url

          # Extract cursor from next URL for pagination
          break unless next_url.include?("cursor=")

          cursor = next_url.match(/cursor=([^&]+)/)[1]
          query_params[:cursor] = cursor

          page_number += 1
        end

        # Clear the dynamic pagination line if we didn't find anything
        print "\r\e[K"
        nil
      end

      def get_pages_for_label(label_id)
        path = "/wiki/api/v2/labels/#{label_id}/pages"
        query_params = { "body-format" => "storage", limit: 100 }

        log_request("GET", path, query_params)

        response = self.class.get(path, { query: query_params })
        log_response(response, "Pages for label")
        validate_response(response)
        response
      end

      def get_page_content(page_id)
        path = "/rest/api/content/#{page_id}"
        query_params = { expand: "body.storage" }

        log_request("GET", path, query_params)

        response = self.class.get(path, { query: query_params })
        log_response(response, "Page content")
        validate_response(response)
        response
      end

      def validate_response(response)
        return if response.success?

        raise Error, "HTTP #{response.code}: #{response.message}"
      end

      def log_request(method, path, query_params = nil, pagination: false)
        config = Aircana.configuration
        full_url = "#{config.confluence_base_url}#{path}"

        log_parts = ["#{method.upcase} #{full_url}"]

        if query_params && !query_params.empty?
          query_string = query_params.map { |k, v| "#{k}=#{v}" }.join("&")
          log_parts << "Query: #{query_string}"
        end

        log_parts << "Auth: Basic #{config.confluence_username}:***"

        log_message = log_parts.join(" | ")

        if pagination
          # Dynamic logging for pagination - overwrite current line
          print "\r\e[36m🌐 #{log_message}\e[0m\e[K"
        else
          # Normal logging
          Aircana.human_logger.info log_message
        end
      end

      def log_response(response, context = nil, pagination: false)
        # During pagination, suppress response logs to avoid interfering with dynamic request display
        return if pagination

        status_color = response.success? ? "32" : "31" # green for success, red for error
        status_text = response.success? ? "✓" : "✗"

        log_parts = ["\e[#{status_color}m#{status_text} Response: #{response.code}"]
        log_parts << context if context

        if response.body && !response.body.empty?
          body_preview = response.body.length > 200 ? "#{response.body[0..200]}..." : response.body
          log_parts << "Body: #{body_preview}"
        end

        Aircana.human_logger.info "#{log_parts.join(" | ")}\e[0m"
      end

      def handle_api_error(operation, error, message)
        Aircana.human_logger.error "Failed to #{operation}: #{error.message}"
        raise Error, "#{message}: #{error.message}"
      end

      def get_next_page_url(response)
        response.dig("_links", "next")
      end

      def log_pages_found(count, agent)
        Aircana.human_logger.info "Found #{count} pages for agent '#{agent}'"
      end

      def store_page_as_markdown(page, agent)
        content = page&.dig("body", "storage", "value") || fetch_page_content(page&.[]("id"))
        markdown_content = convert_to_markdown(content)

        @local_storage.store_content(
          title: page&.[]("title"),
          content: markdown_content,
          agent: agent
        )
      end
    end
  end
end
