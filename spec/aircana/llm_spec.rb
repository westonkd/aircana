# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::LLM do
  describe ".client" do
    context "when provider is 'claude' or nil" do
      it "returns ClaudeClient when provider is nil" do
        allow(Aircana.configuration).to receive(:llm_provider).and_return(nil)

        client = described_class.client

        expect(client).to be_a(Aircana::LLM::ClaudeClient)
      end

      it "returns ClaudeClient when provider is 'claude'" do
        allow(Aircana.configuration).to receive(:llm_provider).and_return("claude")

        client = described_class.client

        expect(client).to be_a(Aircana::LLM::ClaudeClient)
      end
    end

    context "when provider is 'bedrock'" do
      it "returns BedrockClient" do
        allow(Aircana.configuration).to receive(:llm_provider).and_return("bedrock")

        client = described_class.client

        expect(client).to be_a(Aircana::LLM::BedrockClient)
      end
    end

    context "when provider is unknown" do
      let(:mock_human_logger) { double(warn: nil) }

      before do
        allow(Aircana).to receive(:human_logger).and_return(mock_human_logger)
        allow(Aircana.configuration).to receive(:llm_provider).and_return("unknown-provider")
      end

      it "logs a warning" do
        described_class.client

        expect(mock_human_logger).to have_received(:warn)
          .with("Unknown LLM provider 'unknown-provider', falling back to Claude")
      end

      it "returns ClaudeClient as fallback" do
        client = described_class.client

        expect(client).to be_a(Aircana::LLM::ClaudeClient)
      end
    end
  end
end
