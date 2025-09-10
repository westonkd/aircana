# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::FzfHelper do
  describe ".select_files_interactively" do
    context "when fzf is available" do
      before do
        allow(described_class).to receive(:system).and_return(true)
        allow(described_class).to receive(:`).and_return("file1.rb\nfile2.rb\n")
      end

      it "returns array of selected files" do
        result = described_class.select_files_interactively
        expect(result).to eq(["file1.rb", "file2.rb"])
      end

      it "handles empty selection" do
        allow(described_class).to receive(:`).and_return("")
        result = described_class.select_files_interactively
        expect(result).to eq([])
      end

      it "uses custom header when provided" do
        allow(described_class).to receive(:`).with(anything).and_return("")
        described_class.select_files_interactively(header: "Custom header")
        expect(described_class).to have_received(:`).with(a_string_including("Custom header"))
      end
    end

    context "when fzf is not available" do
      before do
        allow(described_class).to receive(:system).and_return(false)
        allow(Aircana).to receive(:human_logger).and_return(double("logger", error: nil, info: nil))
      end

      it "shows helpful error message and returns empty array" do
        result = described_class.select_files_interactively

        expect(Aircana.human_logger).to have_received(:error).with("fzf is required but not installed")
        expect(Aircana.human_logger).to have_received(:info).with("To install fzf:")
        expect(result).to eq([])
      end
    end

    context "when command fails" do
      before do
        allow(described_class).to receive(:system).and_return(true)
        allow(described_class).to receive(:`).and_raise(StandardError, "Command failed")
        allow(Aircana).to receive(:human_logger).and_return(double("logger", error: nil))
      end

      it "handles errors gracefully" do
        result = described_class.select_files_interactively

        expect(Aircana.human_logger).to have_received(:error).with("File selection failed: Command failed")
        expect(result).to eq([])
      end
    end
  end

  describe "command building" do
    describe ".preview_command" do
      it "prefers bat when available" do
        allow(described_class).to receive(:system).with("which bat", any_args).and_return(true)
        allow(described_class).to receive(:system).with("which head", any_args).and_return(false)

        expect(described_class.send(:preview_command)).to include("bat")
      end

      it "falls back to head when bat unavailable" do
        allow(described_class).to receive(:system).with("which bat", any_args).and_return(false)
        allow(described_class).to receive(:system).with("which head", any_args).and_return(true)

        expect(described_class.send(:preview_command)).to include("head")
      end

      it "falls back to cat when neither available" do
        allow(described_class).to receive(:system).with("which bat", any_args).and_return(false)
        allow(described_class).to receive(:system).with("which head", any_args).and_return(false)

        expect(described_class.send(:preview_command)).to include("cat")
      end
    end

    describe ".generate_file_list_command" do
      it "prefers fd when available" do
        allow(described_class).to receive(:system).with("which fd", any_args).and_return(true)
        allow(described_class).to receive(:system).with("which find", any_args).and_return(false)

        expect(described_class.send(:generate_file_list_command)).to include("fd")
      end

      it "falls back to find when fd unavailable" do
        allow(described_class).to receive(:system).with("which fd", any_args).and_return(false)

        expect(described_class.send(:generate_file_list_command)).to include("find")
      end
    end
  end
end
