# frozen_string_literal: true

require "json"
require_relative "generate"
require_relative "../../generators/project_config_generator"

module Aircana
  module CLI
    module Install
      class << self
        def run
          ensure_output_exists
          ensure_project_config_exists
          install_commands_to_claude
          install_hooks_to_claude
        end

        private

        def ensure_output_exists
          return if Dir.exist?(Aircana.configuration.output_dir)

          Aircana.human_logger.warn("No generated output files-auto generating now...")
          Generate.run
        end

        def ensure_project_config_exists
          project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")
          return if File.exist?(project_json_path)

          Aircana.human_logger.info("Creating project.json for multi-root support...")
          Aircana::Generators::ProjectConfigGenerator.new.generate
        end

        def install_commands_to_claude
          claude_commands_dir = File.join(Aircana.configuration.claude_code_project_config_path, "commands")
          Aircana.create_dir_if_needed(claude_commands_dir)

          copy_command_files(claude_commands_dir)
          install_agents_to_claude
        end

        def copy_command_files(destination_dir)
          Dir.glob("#{Aircana.configuration.output_dir}/commands/*").each do |file|
            Aircana.human_logger.success("Installing #{file} to #{destination_dir}")
            FileUtils.cp(file, destination_dir)
          end
        end

        def install_agents_to_claude
          claude_agents_dir = File.join(Aircana.configuration.claude_code_project_config_path, "agents")
          Aircana.create_dir_if_needed(claude_agents_dir)

          copy_agent_files(claude_agents_dir)
        end

        def copy_agent_files(destination_dir)
          agent_files_pattern = File.join(Aircana.configuration.claude_code_project_config_path, "agents", "*.md")
          Dir.glob(agent_files_pattern).each do |file|
            agent_name = File.basename(file, ".md")
            next unless default_agent?(agent_name)

            destination_file = File.join(destination_dir, File.basename(file))
            # Skip copying if source and destination are the same
            next if File.expand_path(file) == File.expand_path(destination_file)

            Aircana.human_logger.success("Installing default agent #{file} to #{destination_dir}")
            FileUtils.cp(file, destination_dir)
          end
        end

        def default_agent?(agent_name)
          require_relative "../../generators/agents_generator"
          Aircana::Generators::AgentsGenerator.available_default_agents.include?(agent_name)
        end

        def install_hooks_to_claude
          return unless Dir.exist?(Aircana.configuration.hooks_dir)

          settings_file = File.join(Aircana.configuration.claude_code_project_config_path, "settings.local.json")
          install_hooks_to_settings(settings_file)
        end

        def install_hooks_to_settings(settings_file)
          settings = load_settings(settings_file)
          hook_configs = build_hook_configs

          return if hook_configs.empty?

          settings["hooks"] = hook_configs
          save_settings(settings_file, settings)

          Aircana.human_logger.success("Installed hooks to #{settings_file}")
        end

        def load_settings(settings_file)
          if File.exist?(settings_file)
            JSON.parse(File.read(settings_file))
          else
            Aircana.create_dir_if_needed(File.dirname(settings_file))
            {}
          end
        rescue JSON::ParserError
          Aircana.human_logger.warn("Invalid JSON in #{settings_file}, creating new settings")
          {}
        end

        def save_settings(settings_file, settings)
          File.write(settings_file, JSON.pretty_generate(settings))
        end

        def build_hook_configs
          hooks = {}

          # Map hook files to Claude Code hook events and their properties
          hook_mappings = {
            "pre_tool_use" => { event: "PreToolUse", matcher: nil },
            "post_tool_use" => { event: "PostToolUse", matcher: nil },
            "user_prompt_submit" => { event: "UserPromptSubmit", matcher: nil },
            "session_start" => { event: "SessionStart", matcher: nil },
            "rubocop_pre_commit" => { event: "PreToolUse", matcher: "Bash" },
            "rspec_test" => { event: "PostToolUse", matcher: "Bash" },
            "bundle_install" => { event: "PostToolUse", matcher: "Bash" }
          }

          Dir.glob("#{Aircana.configuration.hooks_dir}/*.sh").each do |hook_file|
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

            # Create relative path from project root
            relative_path = File.join(".aircana", "hooks", "#{hook_name}.sh")

            hook_entry = {
              "hooks" => [
                {
                  "type" => "command",
                  "command" => relative_path
                }
              ]
            }

            # Add matcher if specified
            hook_entry["matcher"] = mapping[:matcher] if mapping[:matcher]

            hooks[event_key] ||= []
            hooks[event_key] << hook_entry
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
      end
    end
  end
end
