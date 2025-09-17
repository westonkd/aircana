# frozen_string_literal: true

require_relative "generate"

module Aircana
  module CLI
    module Install
      class << self
        def run
          ensure_output_exists
          install_commands_to_claude
        end

        private

        def ensure_output_exists
          return if Dir.exist?(Aircana.configuration.output_dir)

          Aircana.human_logger.warn("No generated output files-auto generating now...")
          Generate.run
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
      end
    end
  end
end
