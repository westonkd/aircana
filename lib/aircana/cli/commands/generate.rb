# frozen_string_literal: true

require_relative "../../generators/relevant_files_command_generator"
require_relative "../../generators/relevant_files_verbose_results_generator"
require_relative "../../generators/agents_generator"

module Aircana
  module CLI
    module Generate
      class << self
        def generators
          @generators ||= [
            Aircana::Generators::RelevantFilesVerboseResultsGenerator.new,
            Aircana::Generators::RelevantFilesCommandGenerator.new
          ]
        end

        def run
          generators.each(&:generate)
          generate_default_agents
          Aircana.human_logger.success("Re-generated #{Aircana.configuration.output_dir} files.")
        end

        private

        def generate_default_agents
          Aircana::Generators::AgentsGenerator.available_default_agents.each do |agent_name|
            Aircana::Generators::AgentsGenerator.create_default_agent(agent_name)
          end
        end
      end
    end
  end
end
