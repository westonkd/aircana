# frozen_string_literal: true

require "spec_helper"
require "tty-spinner"

RSpec.describe Aircana::LLM::Base do
  let(:base) { described_class.new }
  let(:mock_spinner) { instance_double(TTY::Spinner) }

  before do
    allow(TTY::Spinner).to receive(:new).and_return(mock_spinner)
    allow(mock_spinner).to receive(:auto_spin)
    allow(mock_spinner).to receive(:stop)
    allow(base).to receive(:puts)
  end

  describe "#prompt" do
    it "raises NotImplementedError" do
      expect do
        base.prompt("test")
      end.to raise_error(NotImplementedError, "Subclasses must implement #prompt")
    end
  end

  describe "#truncate_content" do
    it "returns content unchanged when under max length" do
      content = "short content"
      result = base.send(:truncate_content, content, 100)
      expect(result).to eq(content)
    end

    it "truncates content with ellipsis when over max length" do
      content = "a" * 100
      result = base.send(:truncate_content, content, 50)
      expect(result).to eq("#{"a" * 51}...")
    end

    it "uses default max length of 2000" do
      content = "a" * 3000
      result = base.send(:truncate_content, content)
      expect(result.length).to eq(2004)
    end
  end

  describe "spinner methods" do
    describe "#start_spinner" do
      it "creates and starts a spinner" do
        base.send(:start_spinner, "Test message")

        expect(TTY::Spinner).to have_received(:new).with("[:spinner] Test message", format: :dots)
        expect(mock_spinner).to have_received(:auto_spin)
      end
    end

    describe "#success_spinner" do
      it "stops spinner with checkmark when spinner exists" do
        base.send(:start_spinner, "Test")
        base.send(:success_spinner, "Success message")

        expect(mock_spinner).to have_received(:stop).with("✓")
        expect(base).to have_received(:puts).with("Success message")
      end

      it "does nothing when no spinner exists" do
        expect { base.send(:success_spinner, "test") }.not_to raise_error
      end
    end

    describe "#error_spinner" do
      it "stops spinner with cross when spinner exists" do
        base.send(:start_spinner, "Test")
        base.send(:error_spinner, "Error message")

        expect(mock_spinner).to have_received(:stop).with("✗")
        expect(base).to have_received(:puts).with("Error message")
      end

      it "does nothing when no spinner exists" do
        expect { base.send(:error_spinner, "test") }.not_to raise_error
      end
    end
  end
end
