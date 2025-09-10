# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aircana::SystemChecker do
  let(:mock_logger) { instance_double(Aircana::HumanLogger) }

  before do
    allow(Aircana).to receive(:human_logger).and_return(mock_logger)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:success)
    allow(mock_logger).to receive(:error)
    allow(mock_logger).to receive(:warn)
  end

  describe ".check_dependencies?" do
    context "when all required dependencies are available" do
      before do
        allow(described_class).to receive(:system).and_return(true)
      end

      it "returns true and shows success message" do
        result = described_class.check_dependencies?

        expect(result).to be true
        expect(mock_logger).to have_received(:success).with("All dependencies satisfied!")
      end
    end

    context "when required dependencies are missing" do
      before do
        allow(described_class).to receive(:system).with("which fzf", any_args).and_return(false)
        allow(described_class).to receive(:system).with("which git", any_args).and_return(true)
        allow(described_class).to receive(:detect_os).and_return("macOS")
      end

      it "returns false and shows error messages with installation instructions" do
        result = described_class.check_dependencies?

        expect(result).to be false
        expect(mock_logger).to have_received(:error)
          .with("Missing required dependency: fzf (interactive file selection)")
        expect(mock_logger).to have_received(:info).with("Installation instructions for macOS:")
        expect(mock_logger).to have_received(:info).with("  fzf: brew install fzf")
      end
    end

    context "when checking optional dependencies" do
      before do
        allow(described_class).to receive(:system).with("which fzf", any_args).and_return(true)
        allow(described_class).to receive(:system).with("which git", any_args).and_return(true)
        allow(described_class).to receive(:system).with("which bat", any_args).and_return(false)
        allow(described_class).to receive(:system).with("which fd", any_args).and_return(false)
        allow(described_class).to receive(:detect_os).and_return("Ubuntu/Debian")
      end

      it "shows warnings for missing optional dependencies" do
        described_class.check_dependencies?(show_optional: true)

        expect(mock_logger).to have_received(:warn).with("Optional dependency missing: bat (enhanced file previews)")
        expect(mock_logger).to have_received(:info).with("  Fallback: head/cat for basic previews")
        expect(mock_logger).to have_received(:warn).with("Optional dependency missing: fd (fast file searching)")
        expect(mock_logger).to have_received(:info).with("  Fallback: find command for basic file listing")
      end
    end
  end

  describe ".command_available?" do
    it "returns true when command exists" do
      allow(described_class).to receive(:system).with("which test_command", any_args).and_return(true)

      expect(described_class.command_available?("test_command")).to be true
    end

    it "returns false when command does not exist" do
      allow(described_class).to receive(:system).with("which nonexistent", any_args).and_return(false)

      expect(described_class.command_available?("nonexistent")).to be false
    end
  end

  describe ".detect_os" do
    it "detects macOS" do
      stub_const("RbConfig::CONFIG", { "host_os" => "darwin20.0" })

      expect(described_class.detect_os).to eq("macOS")
    end

    it "detects Ubuntu/Debian" do
      stub_const("RbConfig::CONFIG", { "host_os" => "linux-gnu" })
      allow(File).to receive(:exist?).with("/etc/debian_version").and_return(true)

      expect(described_class.detect_os).to eq("Ubuntu/Debian")
    end

    it "detects Fedora/CentOS" do
      stub_const("RbConfig::CONFIG", { "host_os" => "linux-gnu" })
      allow(File).to receive(:exist?).with("/etc/debian_version").and_return(false)
      allow(File).to receive(:exist?).with("/etc/fedora-release").and_return(true)

      expect(described_class.detect_os).to eq("Fedora/CentOS")
    end

    it "detects Arch" do
      stub_const("RbConfig::CONFIG", { "host_os" => "linux-gnu" })
      allow(File).to receive(:exist?).with("/etc/debian_version").and_return(false)
      allow(File).to receive(:exist?).with("/etc/fedora-release").and_return(false)
      allow(File).to receive(:exist?).with("/etc/centos-release").and_return(false)
      allow(File).to receive(:exist?).with("/etc/arch-release").and_return(true)

      expect(described_class.detect_os).to eq("Arch")
    end

    it "defaults to Other for unknown systems" do
      stub_const("RbConfig::CONFIG", { "host_os" => "unknown-os" })

      expect(described_class.detect_os).to eq("Other")
    end
  end
end
