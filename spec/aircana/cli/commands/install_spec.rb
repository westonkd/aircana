# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require_relative "../../../../lib/aircana/cli/commands/install"

RSpec.describe Aircana::CLI::Install do
  let(:test_output_dir) { File.join(Dir.pwd, "spec_output_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_claude_dir) { File.join(Dir.pwd, "spec_claude_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_hooks_dir) { File.join(test_output_dir, "hooks") }
  let(:test_commands_dir) { File.join(test_output_dir, "commands") }
  let(:settings_file) { File.join(test_claude_dir, "settings.local.json") }

  before do
    FileUtils.mkdir_p(test_output_dir)
    FileUtils.mkdir_p(test_claude_dir)
    FileUtils.mkdir_p(test_hooks_dir)
    FileUtils.mkdir_p(test_commands_dir)

    allow(Aircana.configuration).to receive(:output_dir).and_return(test_output_dir)
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
    FileUtils.rm_rf(test_output_dir)
    FileUtils.rm_rf(test_claude_dir)
  end

  describe ".run" do
    context "when output directory doesn't exist" do
      before do
        FileUtils.rm_rf(test_output_dir)
        allow(Aircana::CLI::Generate).to receive(:run)
      end

      it "runs generate first" do
        expect(Aircana::CLI::Generate).to receive(:run)

        described_class.run

        expect(@log_messages).to include([:warn, /No generated output files-auto generating now/])
      end
    end

    context "when output directory exists" do
      before do
        # Create a sample command file
        File.write(File.join(test_commands_dir, "sample-command.md"), "# Sample Command")

        # Mock agents generator for default agents check
        allow(Aircana::Generators::AgentsGenerator).to receive(:available_default_agents).and_return(%w[planner])
        allow(File).to receive(:expand_path).and_call_original
      end

      it "installs commands and hooks without generating" do
        described_class.run

        expect(@log_messages).to include([:success, /Installing.*sample-command.md/])
        expect(Aircana::CLI::Generate).not_to receive(:run)
      end
    end
  end

  describe "hooks installation" do
    let(:hook_files) do
      {
        "pre_tool_use.sh" => "#!/bin/bash\necho 'pre tool use'",
        "post_tool_use.sh" => "#!/bin/bash\necho 'post tool use'",
        "rubocop_pre_commit.sh" => "#!/bin/bash\necho 'rubocop hook'"
      }
    end

    before do
      # Create hook files
      hook_files.each do |filename, content|
        File.write(File.join(test_hooks_dir, filename), content)
      end
    end

    context "when settings file doesn't exist" do
      it "creates new settings file with hooks" do
        described_class.run

        expect(File).to exist(settings_file)

        settings = JSON.parse(File.read(settings_file))
        expect(settings).to have_key("hooks")

        hooks_config = settings["hooks"]
        expect(hooks_config).to have_key("preToolUse")
        expect(hooks_config).to have_key("postToolUse")

        expect(@log_messages).to include([:success, "Installed hooks to #{settings_file}"])
      end
    end

    context "when settings file exists with existing permissions" do
      let(:existing_settings) do
        {
          "permissions" => {
            "allow" => ["Bash(echo:*)"],
            "deny" => []
          }
        }
      end

      before do
        File.write(settings_file, JSON.pretty_generate(existing_settings))
      end

      it "preserves existing settings and adds hooks" do
        described_class.run

        settings = JSON.parse(File.read(settings_file))

        # Existing permissions should be preserved
        expect(settings["permissions"]["allow"]).to include("Bash(echo:*)")

        # Hooks should be added
        expect(settings).to have_key("hooks")
        hooks_config = settings["hooks"]
        expect(hooks_config).to have_key("preToolUse")
        expect(hooks_config).to have_key("postToolUse")
      end
    end

    context "when settings file exists with existing hooks" do
      let(:existing_hooks) do
        {
          "preToolUse" => [
            {
              "script" => "/old/hook.sh",
              "outputType" => "simple"
            }
          ]
        }
      end

      let(:existing_settings) do
        {
          "permissions" => { "allow" => [] },
          "hooks" => existing_hooks
        }
      end

      before do
        File.write(settings_file, JSON.pretty_generate(existing_settings))
      end

      it "replaces existing hooks configuration" do
        described_class.run

        settings = JSON.parse(File.read(settings_file))
        hooks_config = settings["hooks"]

        # Should not contain old hook
        pre_tool_use_hooks = hooks_config["preToolUse"]
        old_hook = pre_tool_use_hooks&.find { |hook| hook["script"] == "/old/hook.sh" }
        expect(old_hook).to be_nil

        # Should contain new hooks
        new_hook = pre_tool_use_hooks&.find { |hook| hook["script"]&.include?("pre_tool_use.sh") }
        expect(new_hook).not_to be_nil
      end
    end

    context "when settings file has invalid JSON" do
      before do
        File.write(settings_file, "{ invalid json")
      end

      it "creates new valid settings" do
        described_class.run

        expect(@log_messages).to include([:warn, /Invalid JSON.*creating new settings/])
        expect(File).to exist(settings_file)
        settings = JSON.parse(File.read(settings_file))
        expect(settings).to have_key("hooks")
      end
    end
  end

  describe ".build_hook_configs" do
    let(:hook_files) do
      {
        "pre_tool_use.sh" => "pre tool use hook",
        "post_tool_use.sh" => "post tool use hook",
        "user_prompt_submit.sh" => "user prompt hook",
        "session_start.sh" => "session start hook",
        "rubocop_pre_commit.sh" => "rubocop hook",
        "rspec_test.sh" => "rspec hook",
        "bundle_install.sh" => "bundle install hook"
      }
    end

    before do
      hook_files.each do |filename, content|
        File.write(File.join(test_hooks_dir, filename), content)
      end
    end

    it "builds correct hook configurations for all hook types" do
      config = described_class.send(:build_hook_configs)

      # Check preToolUse hooks
      expect(config["preToolUse"]).to be_an(Array)
      pre_tool_hooks = config["preToolUse"]
      expect(pre_tool_hooks.length).to eq(2) # pre_tool_use + rubocop_pre_commit

      # Check regular pre_tool_use hook
      pre_tool_hook = pre_tool_hooks.find { |h| h["script"].include?("pre_tool_use.sh") }
      expect(pre_tool_hook).not_to be_nil
      expect(pre_tool_hook["outputType"]).to eq("advanced")
      expect(pre_tool_hook["script"]).to eq(".aircana/hooks/pre_tool_use.sh")

      # Check rubocop hook has tool filter
      rubocop_hook = pre_tool_hooks.find { |h| h["script"].include?("rubocop_pre_commit.sh") }
      expect(rubocop_hook).not_to be_nil
      expect(rubocop_hook["toolFilter"]).to eq(["Bash"])
      expect(rubocop_hook["script"]).to eq(".aircana/hooks/rubocop_pre_commit.sh")

      # Check postToolUse hooks
      expect(config["postToolUse"]).to be_an(Array)
      post_tool_hooks = config["postToolUse"]
      expect(post_tool_hooks.length).to eq(3) # post_tool_use, rspec_test, bundle_install

      # Check that post_tool_use hook has correct path
      post_tool_hook = post_tool_hooks.find { |h| h["script"].include?("post_tool_use.sh") }
      expect(post_tool_hook).not_to be_nil
      expect(post_tool_hook["script"]).to eq(".aircana/hooks/post_tool_use.sh")

      # Check userPromptSubmit hook
      expect(config["userPromptSubmit"]).to be_an(Array)
      expect(config["userPromptSubmit"].length).to eq(1)
      user_prompt_hook = config["userPromptSubmit"].first
      expect(user_prompt_hook["outputType"]).to eq("advanced")

      # Check sessionStart hook
      expect(config["sessionStart"]).to be_an(Array)
      expect(config["sessionStart"].length).to eq(1)
      session_hook = config["sessionStart"].first
      expect(session_hook["outputType"]).to eq("advanced")
    end

    context "when no hook files exist" do
      before do
        FileUtils.rm_rf(test_hooks_dir)
        FileUtils.mkdir_p(test_hooks_dir)
      end

      it "returns empty configuration" do
        config = described_class.send(:build_hook_configs)
        expect(config).to be_empty
      end
    end

    context "with unknown hook files" do
      let(:isolated_hooks_dir) { File.join(Dir.pwd, "spec_isolated_hooks_#{Time.now.to_i}_#{rand(1000)}") }

      before do
        FileUtils.mkdir_p(isolated_hooks_dir)
        allow(Aircana.configuration).to receive(:hooks_dir).and_return(isolated_hooks_dir)

        File.write(File.join(isolated_hooks_dir, "unknown_hook.sh"), "unknown hook content")
        File.write(File.join(isolated_hooks_dir, "post_tool_use.sh"), "known hook content")
      end

      after do
        FileUtils.rm_rf(isolated_hooks_dir)
      end

      it "only includes known hooks" do
        config = described_class.send(:build_hook_configs)

        expect(config).to have_key("postToolUse")
        expect(config).not_to have_key("unknown")

        # Should only have the known post_tool_use hook
        expect(config["postToolUse"].length).to eq(1)
      end
    end
  end

  describe ".load_settings" do
    context "when file exists with valid JSON" do
      let(:valid_settings) { { "permissions" => { "allow" => ["test"] } } }

      before do
        File.write(settings_file, JSON.pretty_generate(valid_settings))
      end

      it "loads and parses the settings" do
        result = described_class.send(:load_settings, settings_file)
        expect(result).to eq(valid_settings)
      end
    end

    context "when file doesn't exist" do
      it "returns empty hash" do
        result = described_class.send(:load_settings, "/nonexistent/file.json")
        expect(result).to eq({})
      end
    end

    context "when file has invalid JSON" do
      before do
        File.write(settings_file, "{ invalid json")
      end

      it "returns empty hash and logs warning" do
        result = described_class.send(:load_settings, settings_file)
        expect(result).to eq({})
        expect(@log_messages).to include([:warn, /Invalid JSON.*creating new settings/])
      end
    end
  end

  describe ".save_settings" do
    let(:settings_data) { { "permissions" => { "allow" => [] }, "hooks" => {} } }

    it "saves settings as formatted JSON" do
      described_class.send(:save_settings, settings_file, settings_data)

      expect(File).to exist(settings_file)
      content = File.read(settings_file)
      parsed = JSON.parse(content)
      expect(parsed).to eq(settings_data)
    end
  end
end
