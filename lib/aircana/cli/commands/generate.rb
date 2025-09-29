# frozen_string_literal: true

require_relative "../../generators/plan_command_generator"
require_relative "../../generators/write_plan_command_generator"
require_relative "../../generators/ask_expert_command_generator"
require_relative "../../generators/agents_generator"
require_relative "../../generators/hooks_generator"
require_relative "../../generators/project_config_generator"

module Aircana
  module CLI
    module Generate
      class << self
        def generators
          @generators ||= [
            Aircana::Generators::PlanCommandGenerator.new,
            Aircana::Generators::WritePlanCommandGenerator.new,
            Aircana::Generators::AskExpertCommandGenerator.new
          ]
        end

        def run
          generators.each(&:generate)
          generate_default_agents
          generate_default_hooks
          generate_project_config
          Aircana.human_logger.success("Re-generated #{Aircana.configuration.output_dir} files.")
        end

        private

        def generate_default_agents
          Aircana::Generators::AgentsGenerator.available_default_agents.each do |agent_name|
            Aircana::Generators::AgentsGenerator.create_default_agent(agent_name)
          end
        end

        def generate_default_hooks
          Aircana::Generators::HooksGenerator.available_default_hooks.each do |hook_name|
            Aircana::Generators::HooksGenerator.create_default_hook(hook_name)
          end
        end

        def generate_project_config
          project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")

          # Only generate if it doesn't already exist
          return if File.exist?(project_json_path)

          Aircana::Generators::ProjectConfigGenerator.new.generate
        end
      end
    end
  end
end
