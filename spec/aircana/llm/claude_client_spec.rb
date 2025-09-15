# frozen_string_literal: true

require "spec_helper"
require "tty-spinner"

RSpec.describe Aircana::LLM::ClaudeClient do
  let(:claude_client) { described_class.new }
  let(:mock_spinner) { instance_double(TTY::Spinner) }

  before do
    # Mock TTY::Spinner to avoid actual terminal output during tests
    allow(TTY::Spinner).to receive(:new).and_return(mock_spinner)
    allow(mock_spinner).to receive(:auto_spin)
    allow(mock_spinner).to receive(:stop)

    # Mock puts to capture output
    allow(claude_client).to receive(:puts)

    # Mock file system checks to force fallback to simple 'claude' command
    allow(File).to receive(:executable?).and_return(false)
    allow(claude_client).to receive(:`).with("which claude").and_return("")
  end

  describe "#prompt" do
    context "when Claude command succeeds" do
      before do
        # Mock successful command execution
        allow(claude_client).to receive(:execute_system_command).and_return("Generated description content\n")
      end

      it "starts spinner with loading message" do
        claude_client.prompt("Test prompt")

        expect(TTY::Spinner).to have_received(:new).with("[:spinner] Generating response with Claude...", format: :dots)
        expect(mock_spinner).to have_received(:auto_spin)
      end

      it "stops spinner with success checkmark" do
        claude_client.prompt("Test prompt")

        expect(mock_spinner).to have_received(:stop).with("✓")
        expect(claude_client).to have_received(:puts).with("Generated response with Claude")
      end

      it "returns stripped response content" do
        result = claude_client.prompt("Test prompt")

        expect(result).to eq("Generated description content")
      end

      it "properly escapes single quotes in prompt" do
        claude_client.prompt("Test prompt with 'single quotes'")

        expected_command = "claude -p 'Test prompt with '\"'\"'single quotes'\"'\"''"
        expect(claude_client).to have_received(:execute_system_command).with(expected_command)
      end
    end

    context "when Claude command fails" do
      before do
        # Mock failed command execution
        allow(claude_client).to receive(:execute_system_command).and_raise(StandardError,
                                                                           "Claude command failed with exit code 1")
      end

      it "stops spinner with error cross" do
        expect do
          claude_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error)

        expect(mock_spinner).to have_received(:stop).with("✗")
        expect(claude_client).to have_received(:puts)
          .with("Failed to generate response: Claude command failed with exit code 1")
      end

      it "raises Aircana::Error with descriptive message" do
        expect do
          claude_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error, "Claude request failed: Claude command failed with exit code 1")
      end
    end

    context "when system command raises an exception" do
      before do
        allow(claude_client).to receive(:execute_system_command).and_raise(StandardError, "System error")
      end

      it "handles exceptions gracefully" do
        expect do
          claude_client.prompt("Test prompt")
        end.to raise_error(Aircana::Error, "Claude request failed: System error")

        expect(mock_spinner).to have_received(:stop).with("✗")
        expect(claude_client).to have_received(:puts).with("Failed to generate response: System error")
      end
    end
  end

  describe "command building" do
    it "properly escapes complex text with various quote types" do
      complex_text = "Text with 'single' and \"double\" quotes"
      expected_command = "claude -p 'Text with '\"'\"'single'\"'\"' and \"double\" quotes'"

      allow(claude_client).to receive(:execute_system_command).and_return("result")

      claude_client.prompt(complex_text)

      expect(claude_client).to have_received(:execute_system_command).with(expected_command)
    end

    it "handles empty text" do
      allow(claude_client).to receive(:execute_system_command).and_return("result")

      claude_client.prompt("")

      expect(claude_client).to have_received(:execute_system_command).with("claude -p ''")
    end
  end

  describe "spinner management" do
    context "when no spinner is active" do
      it "handles success_spinner gracefully" do
        expect { claude_client.send(:success_spinner, "test") }.not_to raise_error
      end

      it "handles error_spinner gracefully" do
        expect { claude_client.send(:error_spinner, "test") }.not_to raise_error
      end
    end
  end
end
