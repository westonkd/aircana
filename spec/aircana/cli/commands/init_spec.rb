# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require_relative "../../../../lib/aircana/cli/commands/init"

RSpec.describe Aircana::CLI::Init do
  let(:test_output_dir) { File.join(Dir.pwd, "spec_output_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_target_dir) { File.join(Dir.pwd, "spec_target_#{Time.now.to_i}_#{rand(1000)}") }
  let(:test_scripts_dir) { File.join(test_target_dir, "scripts") }
  let(:test_hooks_dir) { File.join(test_target_dir, "hooks") }
  let(:test_commands_dir) { File.join(test_output_dir, "commands") }
  let(:settings_file) { File.join(test_target_dir, "settings.local.json") }

  before do
    FileUtils.mkdir_p(test_output_dir)
    FileUtils.mkdir_p(test_target_dir)
    FileUtils.mkdir_p(test_scripts_dir)
    FileUtils.mkdir_p(test_hooks_dir)
    FileUtils.mkdir_p(test_commands_dir)

    allow(Aircana.configuration).to receive(:output_dir).and_return(test_output_dir)
    allow(Aircana.configuration).to receive(:scripts_dir).and_return(test_scripts_dir)
    allow(Aircana.configuration).to receive(:hooks_dir).and_return(test_hooks_dir)
    allow(Aircana.configuration).to receive(:commands_dir).and_return(File.join(test_target_dir, "commands"))
    allow(Aircana.configuration).to receive(:agents_dir).and_return(File.join(test_target_dir, "agents"))
    allow(Aircana.configuration).to receive(:plugin_root).and_return(test_target_dir)
    allow(Aircana.configuration).to receive(:claude_code_project_config_path).and_return(test_target_dir)

    @log_messages = []
    human_logger_double = instance_double("HumanLogger")
    allow(human_logger_double).to receive(:info) { |msg| @log_messages << [:info, msg] }
    allow(human_logger_double).to receive(:warn) { |msg| @log_messages << [:warn, msg] }
    allow(human_logger_double).to receive(:error) { |msg| @log_messages << [:error, msg] }
    allow(human_logger_double).to receive(:success) { |msg| @log_messages << [:success, msg] }
    allow(Aircana).to receive(:human_logger).and_return(human_logger_double)

    # Mock TTY::Prompt to avoid stdin blocking
    prompt_double = instance_double("TTY::Prompt")
    allow(TTY::Prompt).to receive(:new).and_return(prompt_double)
    allow(prompt_double).to receive(:ask).with("Plugin name:", any_args).and_return("test-plugin")
    allow(prompt_double).to receive(:ask).with("Initial version:", any_args).and_return("0.1.0")
    allow(prompt_double).to receive(:ask).with("Plugin description:", any_args).and_return("Test plugin")
    allow(prompt_double).to receive(:ask).with("License:", any_args).and_return("MIT")
    allow(prompt_double).to receive(:ask).with("Author name:", any_args).and_return("Test Author")
    allow(prompt_double).to receive(:yes?).with("Add author email?", any_args).and_return(false)
    allow(prompt_double).to receive(:yes?).with("Add author URL (e.g. GitHub profile)?", any_args).and_return(false)
  end

  after do
    FileUtils.rm_rf(test_output_dir)
    FileUtils.rm_rf(test_target_dir)
  end

  describe ".run" do
    before do
      # Create a sample command file
      File.write(File.join(test_commands_dir, "sample-command.md"), "# Sample Command")

      # Mock agents generator for default agents check
      allow(Aircana::Generators::AgentsGenerator).to receive(:available_default_agents).and_return([])
      allow(File).to receive(:expand_path).and_call_original
      allow(Aircana::CLI::Generate).to receive(:run)
    end

    it "always runs generate first" do
      expect(Aircana::CLI::Generate).to receive(:run)

      described_class.run

      expect(@log_messages).to include([:info, "Generating files..."])
    end

    it "installs commands and hooks after generating" do
      described_class.run

      expect(@log_messages).to include([:success, /Installing command:.*sample-command.md/])
    end
  end

  describe "hooks installation" do
    let(:output_hooks_dir) { File.join(test_output_dir, "hooks") }
    let(:hooks_json_file) { File.join(test_hooks_dir, "hooks.json") }
    let(:hook_files) do
      {
        "pre_tool_use.sh" => "#!/bin/bash\necho 'pre tool use'",
        "post_tool_use.sh" => "#!/bin/bash\necho 'post tool use'",
        "rubocop_pre_commit.sh" => "#!/bin/bash\necho 'rubocop hook'"
      }
    end

    before do
      # Create hook files in the TARGET scripts directory (where generate puts them during init)
      hook_files.each do |filename, content|
        File.write(File.join(test_scripts_dir, filename), content)
      end

      allow(Aircana::CLI::Generate).to receive(:run)
      allow(Aircana::Generators::AgentsGenerator).to receive(:available_default_agents).and_return([])
    end

    context "when hooks.json doesn't exist" do
      it "creates new hooks.json with hooks" do
        described_class.run

        expect(File).to exist(hooks_json_file)

        hooks_config = JSON.parse(File.read(hooks_json_file))
        expect(hooks_config).to have_key("PreToolUse")
        expect(hooks_config).to have_key("PostToolUse")

        expect(@log_messages).to include([:success, "Created hooks manifest at hooks/hooks.json"])
      end
    end
  end

  describe ".build_hooks_config" do
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
        File.write(File.join(test_scripts_dir, filename), content)
      end
    end

    it "builds correct hook configurations for all hook types" do
      config = described_class.send(:build_hooks_config)

      # Check PreToolUse hooks
      expect(config["PreToolUse"]).to be_an(Array)
      pre_tool_hooks = config["PreToolUse"]
      expect(pre_tool_hooks.length).to eq(2) # pre_tool_use + rubocop_pre_commit

      # Check regular pre_tool_use hook
      pre_tool_hook = pre_tool_hooks.find { |h| h.dig("hooks", 0, "command").include?("pre_tool_use.sh") }
      expect(pre_tool_hook).not_to be_nil
      expect(pre_tool_hook.dig("hooks", 0, "type")).to eq("command")
      expect(pre_tool_hook.dig("hooks", 0, "command")).to eq("${CLAUDE_PLUGIN_ROOT}/scripts/pre_tool_use.sh")
      expect(pre_tool_hook["matcher"]).to be_nil

      # Check rubocop hook has matcher
      rubocop_hook = pre_tool_hooks.find { |h| h.dig("hooks", 0, "command").include?("rubocop_pre_commit.sh") }
      expect(rubocop_hook).not_to be_nil
      expect(rubocop_hook["matcher"]).to eq("Bash")
      expect(rubocop_hook.dig("hooks", 0, "command")).to eq("${CLAUDE_PLUGIN_ROOT}/scripts/rubocop_pre_commit.sh")

      # Check PostToolUse hooks
      expect(config["PostToolUse"]).to be_an(Array)
      post_tool_hooks = config["PostToolUse"]
      expect(post_tool_hooks.length).to eq(3) # post_tool_use, rspec_test, bundle_install

      # Check that post_tool_use hook has correct path
      post_tool_hook = post_tool_hooks.find { |h| h.dig("hooks", 0, "command").include?("post_tool_use.sh") }
      expect(post_tool_hook).not_to be_nil
      expect(post_tool_hook.dig("hooks", 0, "command")).to eq("${CLAUDE_PLUGIN_ROOT}/scripts/post_tool_use.sh")

      # Check UserPromptSubmit hook
      expect(config["UserPromptSubmit"]).to be_an(Array)
      expect(config["UserPromptSubmit"].length).to eq(1)
      user_prompt_hook = config["UserPromptSubmit"].first
      expect(user_prompt_hook.dig("hooks", 0, "type")).to eq("command")

      # Check SessionStart hook
      expect(config["SessionStart"]).to be_an(Array)
      expect(config["SessionStart"].length).to eq(1)
      session_hook = config["SessionStart"].first
      expect(session_hook.dig("hooks", 0, "type")).to eq("command")
    end

    context "when no hook files exist" do
      before do
        FileUtils.rm_rf(test_scripts_dir)
        FileUtils.mkdir_p(test_scripts_dir)
      end

      it "returns empty configuration" do
        config = described_class.send(:build_hooks_config)
        expect(config).to be_empty
      end
    end

    context "with unknown hook files" do
      let(:isolated_scripts_dir) { File.join(Dir.pwd, "spec_isolated_scripts_#{Time.now.to_i}_#{rand(1000)}") }

      before do
        FileUtils.mkdir_p(isolated_scripts_dir)
        allow(Aircana.configuration).to receive(:scripts_dir).and_return(isolated_scripts_dir)

        File.write(File.join(isolated_scripts_dir, "unknown_hook.sh"), "unknown hook content")
        File.write(File.join(isolated_scripts_dir, "post_tool_use.sh"), "known hook content")
      end

      after do
        FileUtils.rm_rf(isolated_scripts_dir)
      end

      it "includes both known and custom hooks" do
        config = described_class.send(:build_hooks_config)

        expect(config).to have_key("PostToolUse")

        # Should have both hooks (post_tool_use and unknown_hook which defaults to PostToolUse)
        expect(config["PostToolUse"].length).to eq(2)
      end
    end

    context "with custom hook files having event types in names" do
      let(:isolated_scripts_dir) { File.join(Dir.pwd, "spec_isolated_scripts_#{Time.now.to_i}_#{rand(1000)}") }

      before do
        FileUtils.mkdir_p(isolated_scripts_dir)
        allow(Aircana.configuration).to receive(:scripts_dir).and_return(isolated_scripts_dir)

        # Create custom hooks with event type in name
        File.write(File.join(isolated_scripts_dir, "my_validation_pre_tool_use.sh"), "custom pre hook")
        File.write(File.join(isolated_scripts_dir, "cleanup_after_tool.sh"), "custom post hook")
        File.write(File.join(isolated_scripts_dir, "enhance_user_prompt.sh"), "custom prompt hook")
      end

      after do
        FileUtils.rm_rf(isolated_scripts_dir)
      end

      it "correctly maps custom hooks to appropriate events" do
        config = described_class.send(:build_hooks_config)

        # Check PreToolUse has the validation hook
        expect(config["PreToolUse"]).to be_an(Array)
        expect(config["PreToolUse"].length).to eq(1)
        expect(config["PreToolUse"][0].dig("hooks", 0, "command")).to include("my_validation_pre_tool_use.sh")

        # Check PostToolUse has the cleanup hook
        expect(config["PostToolUse"]).to be_an(Array)
        expect(config["PostToolUse"].length).to eq(1)
        expect(config["PostToolUse"][0].dig("hooks", 0, "command")).to include("cleanup_after_tool.sh")

        # Check UserPromptSubmit has the enhance hook
        expect(config["UserPromptSubmit"]).to be_an(Array)
        expect(config["UserPromptSubmit"].length).to eq(1)
        expect(config["UserPromptSubmit"][0].dig("hooks", 0, "command")).to include("enhance_user_prompt.sh")
      end
    end
  end

  describe ".infer_hook_mapping" do
    it "infers PreToolUse for pre_tool patterns" do
      mapping = described_class.send(:infer_hook_mapping, "my_pre_tool_hook")
      expect(mapping[:event]).to eq("PreToolUse")
      expect(mapping[:matcher]).to be_nil

      mapping = described_class.send(:infer_hook_mapping, "before_tool_validation")
      expect(mapping[:event]).to eq("PreToolUse")
    end

    it "defaults to PostToolUse for post_tool patterns" do
      mapping = described_class.send(:infer_hook_mapping, "my_post_tool_hook")
      expect(mapping[:event]).to eq("PostToolUse")

      mapping = described_class.send(:infer_hook_mapping, "after_tool_execution")
      expect(mapping[:event]).to eq("PostToolUse")
    end

    it "infers UserPromptSubmit for prompt patterns" do
      mapping = described_class.send(:infer_hook_mapping, "user_prompt_enhancer")
      expect(mapping[:event]).to eq("UserPromptSubmit")

      mapping = described_class.send(:infer_hook_mapping, "before_prompt")
      expect(mapping[:event]).to eq("UserPromptSubmit")
    end

    it "infers SessionStart for session patterns" do
      mapping = described_class.send(:infer_hook_mapping, "session_init")
      expect(mapping[:event]).to eq("SessionStart")

      mapping = described_class.send(:infer_hook_mapping, "startup_hook")
      expect(mapping[:event]).to eq("SessionStart")
    end

    it "defaults to PostToolUse for unknown patterns" do
      mapping = described_class.send(:infer_hook_mapping, "some_random_hook")
      expect(mapping[:event]).to eq("PostToolUse")
    end
  end

  describe "directory parameter" do
    let(:custom_dir) { File.join(Dir.pwd, "spec_custom_#{Time.now.to_i}_#{rand(1000)}") }

    before do
      FileUtils.mkdir_p(custom_dir)
      FileUtils.mkdir_p(test_commands_dir)
      File.write(File.join(test_commands_dir, "sample-command.md"), "# Sample Command")

      allow(Aircana::Generators::AgentsGenerator).to receive(:available_default_agents).and_return([])
      allow(Aircana::CLI::Generate).to receive(:run)
    end

    after do
      FileUtils.rm_rf(custom_dir)
    end

    it "uses current directory when no directory is specified" do
      original_project_dir = Aircana.configuration.project_dir

      described_class.run

      # Verify that configuration was used with default directory
      expect(Aircana.configuration.project_dir).to eq(original_project_dir)
    end

    it "installs to specified directory" do
      # Track what paths create_dir_if_needed is called with
      created_paths = []
      allow(Aircana).to receive(:create_dir_if_needed) do |path|
        created_paths << path
        FileUtils.mkdir_p(path)
      end

      described_class.run(directory: custom_dir)

      # Verify that a .claude-plugin directory path in custom_dir was created
      plugin_paths = created_paths.select { |p| p.include?(custom_dir) && p.include?(".claude-plugin") }
      expect(plugin_paths).not_to be_empty
    end

    it "creates directory if it does not exist" do
      nonexistent_dir = File.join(Dir.pwd, "spec_new_#{Time.now.to_i}_#{rand(1000)}")

      # Ensure directory doesn't exist before test
      expect(Dir.exist?(nonexistent_dir)).to be false

      # Track what paths create_dir_if_needed is called with
      created_paths = []
      allow(Aircana).to receive(:create_dir_if_needed) do |path|
        created_paths << path
        FileUtils.mkdir_p(path)
      end

      described_class.run(directory: nonexistent_dir)

      # Verify that the directory was created
      expect(Dir.exist?(nonexistent_dir)).to be true

      # Clean up
      FileUtils.rm_rf(nonexistent_dir)
    end

    it "restores original configuration after run" do
      original_project_dir = Aircana.configuration.project_dir
      original_plugin_root = Aircana.configuration.plugin_root

      described_class.run(directory: custom_dir)

      # Configuration should be restored to original values
      expect(Aircana.configuration.project_dir).to eq(original_project_dir)
      expect(Aircana.configuration.plugin_root).to eq(original_plugin_root)
    end
  end
end
