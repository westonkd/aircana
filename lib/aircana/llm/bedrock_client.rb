# frozen_string_literal: true

require "aws-sdk-bedrockruntime"
require_relative "base"

module Aircana
  module LLM
    class BedrockClient < Base
      DEFAULT_REGION = "us-east-1"
      DEFAULT_MODEL = "anthropic.claude-3-haiku-20240307-v1:0"

      def prompt(text)
        start_spinner("Generating response with Bedrock...")

        begin
          result = invoke_bedrock(text)
          success_spinner("Generated response with Bedrock")
          result.strip
        rescue StandardError => e
          error_spinner("Failed to generate response: #{e.message}")
          raise Error, "Bedrock request failed: #{e.message}"
        end
      end

      private

      def invoke_bedrock(text)
        client = build_client
        response = client.invoke_model(
          model_id: model_id,
          content_type: "application/json",
          accept: "application/json",
          body: build_request_body(text)
        )

        parse_response(response)
      end

      def build_client
        Aws::BedrockRuntime::Client.new(region: region)
      end

      def region
        Aircana.configuration.bedrock_region || DEFAULT_REGION
      end

      def model_id
        Aircana.configuration.bedrock_model || DEFAULT_MODEL
      end

      def build_request_body(text)
        {
          anthropic_version: "bedrock-2023-05-31",
          max_tokens: 1024,
          messages: [
            {
              role: "user",
              content: text
            }
          ]
        }.to_json
      end

      def parse_response(response)
        body = JSON.parse(response.body.read)
        content = body.dig("content", 0, "text")
        raise Error, "No content in Bedrock response" unless content

        content
      end
    end
  end
end
