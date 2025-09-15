# frozen_string_literal: true

require "spec_helper"
require "aircana/cli/commands/work"

RSpec.describe Aircana::CLI::Work do
  let(:claude_agents_dir) { File.join(Aircana.configuration.claude_code_config_path, "agents") }
  let(:worker_agent_path) { File.join(claude_agents_dir, "worker.md") }

  before do
    allow(Aircana.configuration).to receive(:claude_code_config_path).and_return("/tmp/test_claude")
    allow(File).to receive(:exist?).and_call_original
  end

  describe ".run" do
    context "when worker agent exists" do
      let(:claude_path) { File.expand_path("~/.claude/local/claude") }

      before do
        allow(File).to receive(:exist?).with(worker_agent_path).and_return(true)
        allow(File).to receive(:executable?).and_return(false)
        allow(File).to receive(:executable?).with(claude_path).and_return(true)
        allow(described_class).to receive(:system).and_return(true)
      end

      it "launches claude with worker prompt" do
        worker_prompt = "#{claude_path} \"Start a work session with the 'worker' sub-agent\""
        expect(described_class).to receive(:system).with(worker_prompt)

        described_class.run
      end
    end

    context "when worker agent does not exist" do
      let(:claude_path) { File.expand_path("~/.claude/local/claude") }

      before do
        allow(File).to receive(:exist?).with(worker_agent_path).and_return(false)
        allow(File).to receive(:executable?).and_return(false)
        allow(File).to receive(:executable?).with(claude_path).and_return(true)
        allow(Aircana::CLI::Generate).to receive(:run)
        allow(Aircana::CLI::Install).to receive(:run)
        allow(described_class).to receive(:system).and_return(true)
      end

      it "generates and installs agent before launching" do
        expect(Aircana::CLI::Generate).to receive(:run)
        expect(Aircana::CLI::Install).to receive(:run)
        worker_prompt = "#{claude_path} \"Start a work session with the 'worker' sub-agent\""
        expect(described_class).to receive(:system).with(worker_prompt)

        described_class.run
      end
    end

    context "when claude command is not available" do
      before do
        allow(File).to receive(:exist?).with(worker_agent_path).and_return(true)
        allow(File).to receive(:executable?).and_return(false)
        allow(described_class).to receive(:`).and_return("")
      end

      it "shows error message with manual instructions" do
        expect(Aircana.human_logger).to receive(:info).with("Launching Claude Code with worker agent...")
        error_msg = "Claude Code command not found. " \
                    "Please make sure Claude Code is installed and in your PATH."
        expect(Aircana.human_logger).to receive(:error).with(error_msg)
        info_msg = "You can manually start Claude Code and run: " \
                   "Start a work session with the 'worker' sub-agent"
        expect(Aircana.human_logger).to receive(:info).with(info_msg)

        described_class.run
      end
    end
  end
end

