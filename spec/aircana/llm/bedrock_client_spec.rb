# frozen_string_literal: true

require "spec_helper"
require "tty-spinner"
require "aircana/llm/bedrock_client"

RSpec.describe Aircana::LLM::BedrockClient do
  let(:bedrock_client) { described_class.new }
  let(:mock_spinner) { instance_double(TTY::Spinner) }
  let(:mock_aws_client) { double("Aws::BedrockRuntime::Client") }
  let(:mock_response) { double("response") }
  let(:mock_response_body) { StringIO.new('{"content":[{"text":"Generated response"}]}') }

  before do
    allow(TTY::Spinner).to receive(:new).and_return(mock_spinner)
    allow(mock_spinner).to receive(:auto_spin)
    allow(mock_spinner).to receive(:stop)
    allow(bedrock_client).to receive(:puts)
  end

  describe "#prompt" do
    context "when invoking Bedrock" do
      before do
        allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(mock_aws_client)
        allow(mock_aws_client).to receive(:invoke_model).and_return(mock_response)
        allow(mock_response).to receive(:body).and_return(mock_response_body)
      end

      it "starts spinner with loading message" do
        bedrock_client.prompt("Test prompt")

        expect(TTY::Spinner).to have_received(:new)
          .with("[:spinner] Generating response with Bedrock...", format: :dots)
        expect(mock_spinner).to have_received(:auto_spin)
      end

      it "stops spinner with success checkmark" do
        bedrock_client.prompt("Test prompt")

        expect(mock_spinner).to have_received(:stop).with("✓")
        expect(bedrock_client).to have_received(:puts).with("Generated response with Bedrock")
      end

      it "returns stripped response content" do
        result = bedrock_client.prompt("Test prompt")

        expect(result).to eq("Generated response")
      end

      it "uses configured region" do
        allow(Aircana.configuration).to receive(:bedrock_region).and_return("us-west-2")

        bedrock_client.prompt("Test prompt")

        expect(Aws::BedrockRuntime::Client).to have_received(:new).with(region: "us-west-2")
      end

      it "uses default region when not configured" do
        allow(Aircana.configuration).to receive(:bedrock_region).and_return(nil)

        bedrock_client.prompt("Test prompt")

        expect(Aws::BedrockRuntime::Client).to have_received(:new).with(region: "us-east-1")
      end

      it "uses configured model" do
        allow(Aircana.configuration).to receive(:bedrock_model).and_return("custom-model-id")

        bedrock_client.prompt("Test prompt")

        expect(mock_aws_client).to have_received(:invoke_model).with(
          hash_including(model_id: "custom-model-id")
        )
      end

      it "uses default model when not configured" do
        allow(Aircana.configuration).to receive(:bedrock_model).and_return(nil)

        bedrock_client.prompt("Test prompt")

        expect(mock_aws_client).to have_received(:invoke_model).with(
          hash_including(model_id: "anthropic.claude-3-haiku-20240307-v1:0")
        )
      end
    end

    context "when Bedrock API fails" do
      before do
        allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(mock_aws_client)
        allow(mock_aws_client).to receive(:invoke_model).and_raise(StandardError, "API error")
      end

      it "stops spinner with error cross" do
        expect do
          bedrock_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error)

        expect(mock_spinner).to have_received(:stop).with("✗")
        expect(bedrock_client).to have_received(:puts).with("Failed to generate response: API error")
      end

      it "raises Aircana::Error with descriptive message" do
        expect do
          bedrock_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error, "Bedrock request failed: API error")
      end
    end

    context "when response has no content" do
      let(:empty_response_body) { StringIO.new('{"content":[]}') }

      before do
        allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(mock_aws_client)
        allow(mock_aws_client).to receive(:invoke_model).and_return(mock_response)
        allow(mock_response).to receive(:body).and_return(empty_response_body)
      end

      it "raises error when no content in response" do
        expect do
          bedrock_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error, "Bedrock request failed: No content in Bedrock response")
      end
    end
  end

  describe "inheritance" do
    it "inherits from Base" do
      expect(described_class.superclass).to eq(Aircana::LLM::Base)
    end
  end
end
