# frozen_string_literal: true

module Aircana
  module Contexts
    module ConfluenceLogging
      private

      def log_request(method, path, query_params = nil, pagination: false)
        config = Aircana.configuration
        full_url = "#{config.confluence_base_url}#{path}"

        log_parts = build_request_log_parts(method, full_url, query_params, config)
        log_message = log_parts.join(" | ")

        output_request_log(log_message, pagination)
      end

      def log_response(response, context = nil, pagination: false)
        return if pagination

        status_color = response_status_color(response)
        status_text = response.success? ? "✓" : "✗"

        log_parts = build_response_log_parts(response, context, status_color, status_text)

        Aircana.human_logger.info "#{log_parts.join(" | ")}\e[0m"
      end

      def handle_api_error(operation, error, message)
        Aircana.human_logger.error "Failed to #{operation}: #{error.message}"
        raise Error, "#{message}: #{error.message}"
      end

      def build_request_log_parts(method, full_url, query_params, config)
        log_parts = ["#{method.upcase} #{full_url}"]

        if query_params && !query_params.empty?
          query_string = query_params.map { |k, v| "#{k}=#{v}" }.join("&")
          log_parts << "Query: #{query_string}"
        end

        log_parts << "Auth: Basic #{config.confluence_username}:***"
        log_parts
      end

      def output_request_log(log_message, pagination)
        if pagination
          print "\r\e[36m🌐 #{log_message}\e[0m\e[K"
        else
          Aircana.human_logger.info log_message
        end
      end

      def response_status_color(response)
        response.success? ? "32" : "31"
      end

      def build_response_log_parts(response, context, status_color, status_text)
        log_parts = ["\e[#{status_color}m#{status_text} Response: #{response.code}"]
        log_parts << context if context

        if response.body && !response.body.empty?
          body_preview = response.body.length > 200 ? "#{response.body[0..200]}..." : response.body
          log_parts << "Body: #{body_preview}"
        end

        log_parts
      end
    end
  end
end
