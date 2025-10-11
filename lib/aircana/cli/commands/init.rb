# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "generate"
require_relative "../../plugin_manifest"
require_relative "../../hooks_manifest"

module Aircana
  module CLI
    module Init # rubocop:disable Metrics/ModuleLength
      class << self # rubocop:disable Metrics/ClassLength
        def run(directory: nil, plugin_name: nil)
          target_dir = resolve_target_directory(directory)

          with_directory_config(target_dir) do
            # Collect plugin metadata
            metadata = collect_plugin_metadata(target_dir, plugin_name)

            # Create plugin structure
            create_plugin_structure(target_dir)

            # Create plugin manifest
            create_plugin_manifest(target_dir, metadata)

            # Generate and install commands
            generate_files
            install_commands

            # Install hooks
            install_hooks

            # Success message
            display_success_message(metadata)
          end
        end

        private

        def resolve_target_directory(directory)
          return Dir.pwd if directory.nil? || directory.empty?

          dir = File.expand_path(directory)
          FileUtils.mkdir_p(dir)

          dir
        end

        def with_directory_config(target_dir)
          original_project_dir = Aircana.configuration.project_dir
          original_plugin_root = Aircana.configuration.plugin_root

          begin
            # Temporarily override configuration to use target directory
            Aircana.configuration.project_dir = target_dir
            Aircana.configuration.plugin_root = target_dir
            Aircana.configuration.instance_variable_set(:@plugin_manifest_dir,
                                                        File.join(target_dir, ".claude-plugin"))
            Aircana.configuration.instance_variable_set(:@commands_dir, File.join(target_dir, "commands"))
            Aircana.configuration.instance_variable_set(:@agents_dir, File.join(target_dir, "agents"))
            Aircana.configuration.instance_variable_set(:@hooks_dir, File.join(target_dir, "hooks"))
            Aircana.configuration.instance_variable_set(:@scripts_dir, File.join(target_dir, "scripts"))
            Aircana.configuration.instance_variable_set(:@agent_knowledge_dir, File.join(target_dir, "agents"))

            yield
          ensure
            # Restore original configuration
            Aircana.configuration.project_dir = original_project_dir
            Aircana.configuration.plugin_root = original_plugin_root
            Aircana.configuration.instance_variable_set(:@plugin_manifest_dir,
                                                        File.join(original_plugin_root, ".claude-plugin"))
            Aircana.configuration.instance_variable_set(:@commands_dir,
                                                        File.join(original_plugin_root, "commands"))
            Aircana.configuration.instance_variable_set(:@agents_dir, File.join(original_plugin_root, "agents"))
            Aircana.configuration.instance_variable_set(:@hooks_dir, File.join(original_plugin_root, "hooks"))
            Aircana.configuration.instance_variable_set(:@scripts_dir, File.join(original_plugin_root, "scripts"))
            Aircana.configuration.instance_variable_set(:@agent_knowledge_dir,
                                                        File.join(original_plugin_root, "agents"))
          end
        end

        def collect_plugin_metadata(target_dir, plugin_name)
          prompt = TTY::Prompt.new

          default_name = plugin_name || PluginManifest.default_plugin_name(target_dir)

          # Collect basic metadata
          metadata = {
            name: prompt.ask("Plugin name:", default: default_name),
            version: prompt.ask("Initial version:", default: "0.1.0"),
            description: prompt.ask("Plugin description:", default: "A Claude Code plugin created with Aircana"),
            license: prompt.ask("License:", default: "MIT")
          }

          # Collect author information
          author_name = prompt.ask("Author name:")
          author = { "name" => author_name }

          author["email"] = prompt.ask("Author email:") if prompt.yes?("Add author email?", default: false)

          if prompt.yes?("Add author URL (e.g. GitHub profile)?", default: false)
            author["url"] = prompt.ask("Author URL:")
          end

          metadata[:author] = author

          metadata
        end

        def create_plugin_structure(target_dir)
          # Create plugin directories
          [".claude-plugin", "commands", "agents", "hooks", "scripts"].each do |dir|
            dir_path = File.join(target_dir, dir)
            Aircana.create_dir_if_needed(dir_path)
            Aircana.human_logger.info("Created directory: #{dir}/")
          end
        end

        def create_plugin_manifest(target_dir, metadata)
          manifest = PluginManifest.new(target_dir)
          manifest.create(metadata)
          Aircana.human_logger.success("Created plugin manifest at .claude-plugin/plugin.json")
        end

        def generate_files
          Aircana.human_logger.info("Generating files...")
          Generate.run
        end

        def install_commands
          commands_dir = Aircana.configuration.commands_dir
          Aircana.create_dir_if_needed(commands_dir)

          copy_command_files(commands_dir)
          install_default_agents
        end

        def copy_command_files(destination_dir)
          Dir.glob("#{Aircana.configuration.output_dir}/commands/*").each do |file|
            Aircana.human_logger.success("Installing command: #{File.basename(file)}")
            FileUtils.cp(file, destination_dir)
          end
        end

        def install_default_agents
          agents_dir = Aircana.configuration.agents_dir
          Aircana.create_dir_if_needed(agents_dir)

          copy_agent_files(agents_dir)
        end

        def copy_agent_files(destination_dir)
          agent_files_pattern = File.join(Aircana.configuration.output_dir, "agents", "*.md")
          Dir.glob(agent_files_pattern).each do |file|
            agent_name = File.basename(file, ".md")
            next unless default_agent?(agent_name)

            destination_file = File.join(destination_dir, File.basename(file))
            # Skip copying if source and destination are the same
            next if File.expand_path(file) == File.expand_path(destination_file)

            Aircana.human_logger.success("Installing default agent: #{agent_name}")
            FileUtils.cp(file, destination_dir)
          end
        end

        def default_agent?(agent_name)
          require_relative "../../generators/agents_generator"
          Aircana::Generators::AgentsGenerator.available_default_agents.include?(agent_name)
        end

        def install_hooks
          scripts_dir = Aircana.configuration.scripts_dir
          return unless Dir.exist?(scripts_dir)

          # Check if any hook scripts exist (they're already generated to the correct location)
          hook_files = Dir.glob("#{scripts_dir}/*.sh")
          return unless hook_files.any?

          # Create hooks manifest
          create_hooks_manifest
        end

        def create_hooks_manifest
          hooks_config = build_hooks_config

          return if hooks_config.empty?

          manifest = HooksManifest.new(Aircana.configuration.plugin_root)
          manifest.create(hooks_config)

          Aircana.human_logger.success("Created hooks manifest at hooks/hooks.json")
        end

        def build_hooks_config
          hooks = {}

          # Map hook files to Claude Code hook events and their properties
          hook_mappings = {
            "pre_tool_use" => { event: "PreToolUse", matcher: nil },
            "post_tool_use" => { event: "PostToolUse", matcher: nil },
            "user_prompt_submit" => { event: "UserPromptSubmit", matcher: nil },
            "session_start" => { event: "SessionStart", matcher: nil },
            "refresh_agents" => { event: "SessionStart", matcher: nil },
            "notification_sqs" => { event: "Notification", matcher: nil },
            "rubocop_pre_commit" => { event: "PreToolUse", matcher: "Bash" },
            "rspec_test" => { event: "PostToolUse", matcher: "Bash" },
            "bundle_install" => { event: "PostToolUse", matcher: "Bash" }
          }

          Dir.glob("#{Aircana.configuration.scripts_dir}/*.sh").each do |hook_file|
            hook_name = File.basename(hook_file, ".sh")

            # Determine mapping for this hook
            mapping = if hook_mappings.key?(hook_name)
                        hook_mappings[hook_name]
                      else
                        # For custom hooks, try to infer the event type from the filename
                        infer_hook_mapping(hook_name)
                      end

            next unless mapping

            event_key = mapping[:event]

            # Create relative path using ${CLAUDE_PLUGIN_ROOT}
            relative_path = "${CLAUDE_PLUGIN_ROOT}/scripts/#{hook_name}.sh"

            hook_entry = {
              "type" => "command",
              "command" => relative_path
            }

            hook_config = {
              "hooks" => [hook_entry]
            }

            # Add matcher if specified
            hook_config["matcher"] = mapping[:matcher] if mapping[:matcher]

            hooks[event_key] ||= []
            hooks[event_key] << hook_config
          end

          hooks
        end

        def infer_hook_mapping(hook_name)
          # Try to infer the event type from common patterns in the hook name
          case hook_name
          when /pre_tool_use|pre_tool|before_tool/i
            { event: "PreToolUse", matcher: nil }
          when /user_prompt|prompt_submit|before_prompt/i
            { event: "UserPromptSubmit", matcher: nil }
          when /session_start|session_init|startup/i
            { event: "SessionStart", matcher: nil }
          else
            # Default to PostToolUse for unknown custom hooks and post_tool patterns
            { event: "PostToolUse", matcher: nil }
          end
        end

        def display_success_message(metadata)
          Aircana.human_logger.success("\nPlugin '#{metadata[:name]}' initialized successfully!")
          Aircana.human_logger.info("\nPlugin structure:")
          Aircana.human_logger.info("  .claude-plugin/plugin.json  - Plugin metadata")
          Aircana.human_logger.info("  commands/                   - Slash commands")
          Aircana.human_logger.info("  agents/                     - Specialized agents")
          Aircana.human_logger.info("  hooks/                      - Event hook configurations")
          Aircana.human_logger.info("  scripts/                    - Hook scripts and utilities")
          Aircana.human_logger.info("\nNext steps:")
          Aircana.human_logger.info("  - Create agents: aircana agents create")
          Aircana.human_logger.info("  - Install plugin in Claude Code")
          Aircana.human_logger.info("  - Run: aircana plugin info")
        end
      end
    end
  end
end
