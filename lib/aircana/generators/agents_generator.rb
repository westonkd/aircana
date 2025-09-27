# frozen_string_literal: true

require_relative "../generators"

module Aircana
  module Generators
    class AgentsGenerator < BaseGenerator
      attr_reader :agent_name, :short_description, :description, :model, :color, :default_agent

      AVAILABLE_DEFAULT_AGENTS = ["planner"].freeze

      class << self
        def create_default_agent(agent_name)
          unless AVAILABLE_DEFAULT_AGENTS.include?(agent_name)
            raise ArgumentError, "Unknown default agent: #{agent_name}"
          end

          new(agent_name: agent_name, default_agent: true).generate
        end

        def available_default_agents
          AVAILABLE_DEFAULT_AGENTS
        end
      end

      def initialize( # rubocop:disable Metrics/ParameterLists
        agent_name:, short_description: nil, description: nil, model: nil, color: nil,
        file_in: nil, file_out: nil, default_agent: false
      )
        @agent_name = agent_name
        @short_description = short_description
        @description = description
        @model = model
        @color = color
        @default_agent = default_agent

        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      protected

      def locals
        super.merge({
                      relevant_project_files_path:, agent_name:, short_description:, description:,
                      model:, color:, knowledge_path:
                    })
      end

      private

      def default_template_path
        if default_agent
          File.join(File.dirname(__FILE__), "..", "templates", "agents", "defaults", "#{agent_name}.erb")
        else
          File.join(File.dirname(__FILE__), "..", "templates", "agents", "base_agent.erb")
        end
      end

      def default_output_path
        File.join(Aircana.configuration.claude_code_project_config_path, "agents", "#{agent_name}.md")
      end

      def relevant_project_files_path
        File.join(Aircana.configuration.relevant_project_files_dir, "relevant_files.md")
      end

      def knowledge_path
        ".aircana/agents/#{agent_name}/knowledge/"
      end
    end
  end
end
