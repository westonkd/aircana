# frozen_string_literal: true

require "httparty"
require "reverse_markdown"
require_relative "local"
require_relative "manifest"
require_relative "confluence_logging"
require_relative "confluence_http"
require_relative "confluence_content"
require_relative "confluence_setup"

module Aircana
  module Contexts
    class Confluence
      include HTTParty
      include ConfluenceLogging
      include ConfluenceHttp
      include ConfluenceContent
      include ConfluenceSetup

      LABEL_PREFIX = "global"

      def initialize
        @local_storage = Local.new
      end

      def fetch_pages_for(agent:)
        validate_configuration!
        setup_httparty

        pages = search_and_log_pages(agent)
        return { pages_count: 0, sources: [] } if pages.empty?

        sources = process_pages_with_manifest(pages, agent)
        create_or_update_manifest(agent, sources)

        { pages_count: pages.size, sources: sources }
      end

      def refresh_from_manifest(agent:)
        sources = Manifest.sources_from_manifest(agent)
        return { pages_count: 0, sources: [] } if sources.empty?

        validate_configuration!
        setup_httparty

        confluence_sources = sources.select { |s| s["type"] == "confluence" }
        return { pages_count: 0, sources: [] } if confluence_sources.empty?

        all_pages = []
        confluence_sources.each do |source|
          pages = fetch_pages_from_source(source)
          all_pages.concat(pages)
        end

        return { pages_count: 0, sources: [] } if all_pages.empty?

        updated_sources = process_pages_with_manifest(all_pages, agent)

        { pages_count: all_pages.size, sources: updated_sources }
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

      def process_pages_with_manifest(pages, agent)
        page_metadata = []

        ProgressTracker.with_batch_progress(pages, "Processing pages") do |page, _index|
          store_page_as_markdown(page, agent)
          page_metadata << extract_page_metadata(page)
        end

        build_source_metadata(agent, page_metadata)
      end

      private

      def fetch_pages_from_source(source)
        case source["type"]
        when "confluence"
          fetch_pages_by_label(source["label"])
        else
          []
        end
      end

      def extract_page_metadata(page)
        {
          "id" => page["id"],
          "title" => page["title"],
          "last_updated" => page.dig("version", "when") || Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
      end

      def build_source_metadata(agent, page_metadata)
        [
          {
            "type" => "confluence",
            "label" => agent,
            "pages" => page_metadata
          }
        ]
      end

      def create_or_update_manifest(agent, sources)
        if Manifest.manifest_exists?(agent)
          Manifest.update_manifest(agent, sources)
        else
          Manifest.create_manifest(agent, sources)
        end
      end

      def validate_configuration!
        config = Aircana.configuration

        validate_base_url(config)
        validate_username(config)
        validate_api_token(config)
      end

      def validate_base_url(config)
        return unless config.confluence_base_url.nil? || config.confluence_base_url.empty?

        raise Error, "Confluence base URL not configured"
      end

      def validate_username(config)
        return unless config.confluence_username.nil? || config.confluence_username.empty?

        raise Error, "Confluence username not configured"
      end

      def validate_api_token(config)
        return unless config.confluence_api_token.nil? || config.confluence_api_token.empty?

        raise Error, "Confluence API token not configured"
      end

      def fetch_pages_by_label(agent)
        label_id = find_label_id(agent)
        return [] if label_id.nil?

        response = get_pages_for_label(label_id)
        response["results"] || []
      rescue HTTParty::Error, StandardError => e
        handle_api_error("fetch pages for agent '#{agent}'", e, "Failed to fetch pages from Confluence")
      end

      def find_label_id(agent_name)
        path = "/wiki/api/v2/labels"
        query_params = { limit: 250, prefix: LABEL_PREFIX }
        page_number = 1

        label_id = search_labels_pagination(path, query_params, agent_name, page_number)
        clear_pagination_line
        label_id
      end

      def search_labels_pagination(path, query_params, agent_name, page_number)
        loop do
          response = fetch_labels_page(path, query_params, page_number)
          label_id = find_matching_label_id(response, agent_name)
          return label_id if label_id

          next_cursor = extract_next_cursor(response)
          break unless next_cursor

          query_params[:cursor] = next_cursor
          page_number += 1
        end

        nil
      end

      def fetch_labels_page(path, query_params, page_number)
        log_request("GET", path, query_params.merge("Page" => page_number), pagination: true)
        response = self.class.get(path, { query: query_params })
        log_response(response, "Labels lookup (page #{page_number})", pagination: true)
        validate_response(response)
        response
      end

      def find_matching_label_id(response, agent_name)
        labels = response["results"] || []
        matching_label = labels.find { |label| label["name"] == agent_name }
        matching_label&.[]("id")
      end

      def extract_next_cursor(response)
        next_url = get_next_page_url(response)
        return nil unless next_url&.include?("cursor=")

        next_url.match(/cursor=([^&]+)/)[1]
      end

      def clear_pagination_line
        print "\r\e[K"
      end
    end
  end
end
