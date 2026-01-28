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

      def fetch_pages_for(kb_name:, label: nil)
        validate_configuration!
        setup_httparty

        label_to_search = label || kb_name
        pages = search_and_log_pages(label_to_search)
        return { pages_count: 0, sources: [] } if pages.empty?

        sources = process_pages_with_manifest(pages, kb_name, label_to_search)
        create_or_update_manifest(kb_name, sources)

        { pages_count: pages.size, sources: sources }
      end

      def refresh_from_manifest(kb_name:)
        sources = Manifest.sources_from_manifest(kb_name)
        return { pages_count: 0, sources: [] } if sources.empty?

        validate_configuration!
        setup_httparty

        confluence_sources = sources.select { |s| s["type"] == "confluence" }
        return { pages_count: 0, sources: [] } if confluence_sources.empty?

        all_pages = []
        labels_used = []

        confluence_sources.each do |source|
          label = source["label"] || kb_name
          labels_used << label
          pages = fetch_pages_by_label(label)
          all_pages.concat(pages)
        end

        return { pages_count: 0, sources: [] } if all_pages.empty?

        updated_sources = process_pages_with_manifest(all_pages, kb_name, labels_used.first)

        { pages_count: all_pages.size, sources: updated_sources }
      end

      def search_and_log_pages(label)
        pages = ProgressTracker.with_spinner("Searching for pages labeled '#{label}'") do
          fetch_pages_by_label(label)
        end
        log_pages_found(pages.size, label)
        pages
      end

      def process_pages(pages, kb_name)
        ProgressTracker.with_batch_progress(pages, "Processing pages") do |page, _index|
          store_page_as_markdown(page, kb_name)
        end
      end

      def process_pages_with_manifest(pages, kb_name, label = nil)
        page_metadata = []
        existing_metadata = load_existing_page_metadata(kb_name)

        ProgressTracker.with_batch_progress(pages, "Processing pages") do |page, _index|
          store_page_as_markdown(page, kb_name)
          page_metadata << extract_page_metadata(page, existing_metadata: existing_metadata)
        end

        build_source_metadata(kb_name, page_metadata, label)
      end

      private

      def load_existing_page_metadata(kb_name)
        sources = Manifest.sources_from_manifest(kb_name)
        confluence_sources = sources.select { |s| s["type"] == "confluence" }
        return {} if confluence_sources.empty?

        metadata = {}
        confluence_sources.each do |source|
          (source["pages"] || []).each do |page|
            metadata[page["id"]] = page
          end
        end
        metadata
      end

      def extract_page_metadata(page, existing_metadata: nil)
        existing_metadata ||= {}
        content = page&.dig("body", "storage", "value") || ""
        markdown_content = convert_to_markdown(content)
        title = page["title"] || "Confluence page"
        content_checksum = Aircana::Checksum.compute(markdown_content)

        existing = existing_metadata[page["id"]]
        summary = if existing && Aircana::Checksum.match?(existing["content_checksum"], markdown_content)
                    Aircana.human_logger.info("Content unchanged for '#{title}', reusing summary")
                    existing["summary"]
                  else
                    generate_summary(markdown_content, title)
                  end

        {
          "id" => page["id"],
          "title" => title,
          "summary" => summary,
          "content_checksum" => content_checksum
        }
      end

      def generate_summary(content, title)
        prompt = build_summary_prompt(content, title)
        Aircana::LLM.client.prompt(prompt).strip
      rescue StandardError => e
        Aircana.human_logger.warn("Failed to generate summary: #{e.message}")
        # Fallback to title or truncated content
        title || "#{content[0..80].gsub(/\s+/, " ").strip}..."
      end

      def build_summary_prompt(content, title)
        truncated_content = content.length > 10_000 ? "#{content[0..10_000]}..." : content

        <<~PROMPT
          Generate a concise 8-12 word summary of the following documentation.
          Title: #{title}

          Content:
          #{truncated_content}

          Focus your summary on listing each topic or feature covered in the documentation.

          Respond with only the summary text, no additional explanation or formatting.
        PROMPT
      end

      def build_source_metadata(_kb_name, page_metadata, label = nil)
        source = {
          "type" => "confluence",
          "pages" => page_metadata
        }
        # Add label if provided so refresh can use it to discover new pages
        source["label"] = label if label

        [source]
      end

      def create_or_update_manifest(kb_name, sources)
        if Manifest.manifest_exists?(kb_name)
          Manifest.update_manifest(kb_name, sources)
        else
          Manifest.create_manifest(kb_name, sources)
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
