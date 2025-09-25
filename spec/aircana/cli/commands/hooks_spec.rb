# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require_relative "../../../../lib/aircana/cli/commands/hooks"

RSpec.describe Aircana::CLI::Hooks do
  let(:test_hooks_dir) { File.join(Dir.pwd, "spec_hooks_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_claude_dir) { File.join(Dir.pwd, "spec_claude_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_settings_file) { File.join(test_claude_dir, "settings.local.json") }

  before do
    FileUtils.mkdir_p(test_hooks_dir)
    FileUtils.mkdir_p(test_claude_dir)
    allow(Aircana.configuration).to receive(:hooks_dir).and_return(test_hooks_dir)
    allow(Aircana.configuration).to receive(:claude_code_project_config_path).and_return(test_claude_dir)

    @log_messages = []
    human_logger_double = instance_double("HumanLogger")
    allow(human_logger_double).to receive(:info) { |msg| @log_messages << [:info, msg] }
    allow(human_logger_double).to receive(:warn) { |msg| @log_messages << [:warn, msg] }
    allow(human_logger_double).to receive(:error) { |msg| @log_messages << [:error, msg] }
    allow(human_logger_double).to receive(:success) { |msg| @log_messages << [:success, msg] }
    allow(Aircana).to receive(:human_logger).and_return(human_logger_double)
    allow(Aircana).to receive(:create_dir_if_needed)
  end

  after do
    FileUtils.rm_rf(test_hooks_dir)
    FileUtils.rm_rf(test_claude_dir)
  end

  describe ".list" do
    context "when no hooks are available" do
      before do
        allow(Aircana::Generators::HooksGenerator).to receive(:all_available_hooks).and_return([])
      end

      it "shows no hooks available message" do
        described_class.list

        expect(@log_messages).to include([:info, "No hooks available."])
      end
    end

    context "with available hooks" do
      let(:available_hooks) { %w[pre_tool_use post_tool_use rubocop_pre_commit] }

      before do
        allow(Aircana::Generators::HooksGenerator).to receive(:all_available_hooks).and_return(available_hooks)
        allow(Aircana::Generators::HooksGenerator).to receive(:available_default_hooks).and_return(["session_start"])
      end

      context "when no hooks are installed" do
        it "shows all hooks as available" do
          described_class.list

          expect(@log_messages).to include([:info, "Available Hooks:"])
          expect(@log_messages).to include([:info, "  [AVAILABLE] pre_tool_use - General pre-tool validation hook"])
          expect(@log_messages).to include([:info, "  [AVAILABLE] post_tool_use - General post-tool processing hook"])
          expect(@log_messages).to include([:info, "  [AVAILABLE] rubocop_pre_commit - Run RuboCop before git commits"])
        end
      end

      context "when some hooks are installed" do
        before do
          # Create installed hook files
          File.write(File.join(test_hooks_dir, "pre_tool_use.sh"), "#!/bin/bash\necho 'pre tool use hook'")
          File.write(File.join(test_hooks_dir, "rubocop_pre_commit.sh"), "#!/bin/bash\necho 'rubocop hook'")
        end

        it "shows correct installed/available status" do
          described_class.list

          expect(@log_messages).to include([:info, "  [INSTALLED] pre_tool_use - General pre-tool validation hook"])
          expect(@log_messages).to include([:info, "  [AVAILABLE] post_tool_use - General post-tool processing hook"])
          expect(@log_messages).to include([:info, "  [INSTALLED] rubocop_pre_commit - Run RuboCop before git commits"])
        end
      end
    end
  end

  describe ".enable" do
    let(:hook_name) { "pre_tool_use" }
    let(:available_hooks) { %w[pre_tool_use post_tool_use] }

    before do
      allow(Aircana::Generators::HooksGenerator).to receive(:all_available_hooks).and_return(available_hooks)
    end

    context "when hook is not available" do
      it "shows error and available hooks" do
        described_class.enable("unknown_hook")

        expect(@log_messages).to include([:error, "Hook 'unknown_hook' is not available."])
        expect(@log_messages).to include([:info, "Available hooks: pre_tool_use, post_tool_use"])
      end
    end

    context "when hook is available" do
      let(:install_double) { class_double(Aircana::CLI::Install) }

      before do
        allow(Aircana::Generators::HooksGenerator).to receive(:create_default_hook).and_return("/path/to/hook.sh")
        allow(Aircana::CLI::Install).to receive(:run)
      end

      it "creates hook and runs install" do
        expect(Aircana::Generators::HooksGenerator).to receive(:create_default_hook).with(hook_name)
        expect(Aircana::CLI::Install).to receive(:run)

        described_class.enable(hook_name)

        expect(@log_messages).to include([:success, "Hook 'pre_tool_use' has been enabled."])
      end
    end
  end

  describe ".disable" do
    let(:hook_name) { "pre_tool_use" }
    let(:hook_file) { File.join(test_hooks_dir, "#{hook_name}.sh") }

    context "when hook is not currently enabled" do
      it "shows warning message" do
        described_class.disable(hook_name)

        expect(@log_messages).to include([:warn, "Hook 'pre_tool_use' is not currently enabled."])
      end
    end

    context "when hook is currently enabled" do
      before do
        File.write(hook_file, "#!/bin/bash\necho 'test hook'")
        allow(Aircana::CLI::Install).to receive(:run)
      end

      it "deletes hook file and runs install" do
        expect(File).to exist(hook_file)

        described_class.disable(hook_name)

        expect(File).not_to exist(hook_file)
        expect(@log_messages).to include([:success, "Hook 'pre_tool_use' has been disabled."])
      end
    end
  end

  describe ".create" do
    let(:prompt_double) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(prompt_double)
      allow(prompt_double).to receive(:ask).with("Hook name (lowercase, no spaces):").and_return("my_custom_hook")
      allow(prompt_double).to receive(:ask)
        .with("Brief description of what this hook does:")
        .and_return("My custom hook")
      allow(prompt_double).to receive(:select).with("Select hook event:", %w[
                                                      pre_tool_use
                                                      post_tool_use
                                                      user_prompt_submit
                                                      session_start
                                                    ]).and_return("pre_tool_use")
      allow(prompt_double).to receive(:yes?).with("Would you like to edit the hook file now?").and_return(false)
      allow(Aircana::CLI::Install).to receive(:run)
    end

    it "creates custom hook with user input and installs to Claude settings" do
      expect(Aircana::CLI::Install).to receive(:run)

      described_class.create

      # Hook name should include the event type
      expected_hook_file = File.join(test_hooks_dir, "my_custom_hook_pre_tool_use.sh")
      expect(File).to exist(expected_hook_file)

      # Check that file is executable
      expect(File.executable?(expected_hook_file)).to be true

      # Check content contains expected elements
      content = File.read(expected_hook_file)
      expect(content).to include("#!/bin/bash")
      expect(content).to include("My custom hook")

      expect(@log_messages).to include([:success, "Custom hook created at #{expected_hook_file}"])
      expect(@log_messages).to include([:success, "Hook installed to Claude settings"])
    end

    context "when user wants to edit hook file" do
      before do
        allow(prompt_double).to receive(:yes?).with("Would you like to edit the hook file now?").and_return(true)
        allow(ENV).to receive(:[]).with("EDITOR").and_return("nano")
        allow(described_class).to receive(:system)
      end

      it "opens file in editor" do
        expect(described_class).to receive(:system).with(/nano/)

        described_class.create
      end
    end
  end

  describe ".status" do
    context "when settings file doesn't exist" do
      it "shows no settings file message" do
        described_class.status

        expect(@log_messages).to include([:info, /No Claude settings file found/])
      end
    end

    context "when settings file exists but has no hooks" do
      before do
        File.write(test_settings_file, JSON.pretty_generate({ "permissions" => { "allow" => [] } }))
      end

      it "shows no hooks configured message" do
        described_class.status

        expect(@log_messages).to include([:info, "No hooks configured in Claude settings."])
      end
    end

    context "when settings file has hooks configured" do
      let(:hooks_config) do
        {
          "PreToolUse" => [
            {
              "hooks" => [
                {
                  "type" => "command",
                  "command" => "/path/to/pre_tool_use.sh"
                }
              ]
            }
          ],
          "PostToolUse" => [
            {
              "hooks" => [
                {
                  "type" => "command",
                  "command" => "/path/to/post_tool_use.sh"
                }
              ]
            }
          ]
        }
      end

      before do
        settings = {
          "permissions" => { "allow" => [] },
          "hooks" => hooks_config
        }
        File.write(test_settings_file, JSON.pretty_generate(settings))
      end

      it "shows configured hooks" do
        described_class.status

        expect(@log_messages).to include([:info, "Configured hooks in Claude settings:"])
        expect(@log_messages).to include([:info, "  PreToolUse: pre_tool_use"])
        expect(@log_messages).to include([:info, "  PostToolUse: post_tool_use"])
      end
    end

    context "when settings file has invalid JSON" do
      before do
        File.write(test_settings_file, "{ invalid json")
      end

      it "shows JSON parsing error" do
        described_class.status

        expect(@log_messages).to include([:error, /Invalid JSON in settings file/])
      end
    end
  end

  describe ".installed_hooks" do
    context "when hooks directory doesn't exist" do
      before do
        FileUtils.rm_rf(test_hooks_dir)
      end

      it "returns empty array" do
        result = described_class.send(:installed_hooks)
        expect(result).to eq([])
      end
    end

    context "when hooks directory exists with hook files" do
      before do
        File.write(File.join(test_hooks_dir, "pre_tool_use.sh"), "hook content")
        File.write(File.join(test_hooks_dir, "rubocop_pre_commit.sh"), "hook content")
        File.write(File.join(test_hooks_dir, "not_a_hook.txt"), "not a hook")
      end

      it "returns only .sh files" do
        result = described_class.send(:installed_hooks)
        expect(result).to contain_exactly("pre_tool_use", "rubocop_pre_commit")
      end
    end
  end

  describe ".hook_description" do
    it "returns correct descriptions for known hooks" do
      expect(described_class.send(:hook_description, "pre_tool_use")).to eq("General pre-tool validation hook")
      expect(described_class.send(:hook_description, "rubocop_pre_commit")).to eq("Run RuboCop before git commits")
      expect(described_class.send(:hook_description, "unknown_hook")).to eq("Custom hook")
    end
  end
end
