# frozen_string_literal: true

module Aircana
  module Contexts
    module ConfluenceHttp
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

      def get_next_page_url(response)
        response.dig("_links", "next")
      end
    end
  end
end
