# frozen_string_literal: true

require_relative "../generators"

module Aircana
  module Generators
    class AgentsGenerator < BaseGenerator
      attr_reader :agent_name, :short_description, :description, :model, :color

      def initialize(agent_name:, short_description:, description:, model:, color:, file_in: nil, file_out: nil) # rubocop:disable Metrics/ParameterLists
        @agent_name = agent_name
        @short_description = short_description
        @description = description
        @model = model
        @color = color

        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      protected

      def locals
        super.merge({ relevant_project_files_path:, agent_name:, short_description:, description:, model:, color: })
      end

      private

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "agents", "base_agent.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.claude_code_project_config_path, "agents", "#{agent_name}.md")
      end

      def relevant_project_files_path
        File.join(Aircana.configuration.relevant_project_files_dir, "relevant_files.md")
      end
    end
  end
end
