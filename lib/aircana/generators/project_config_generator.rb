# frozen_string_literal: true

require_relative "base_generator"
require "json"

module Aircana
  module Generators
    class ProjectConfigGenerator < BaseGenerator
      def initialize(file_in: nil, file_out: nil)
        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      def generate
        # Create the project.json with default content
        project_config = default_project_config

        Aircana.create_dir_if_needed(File.dirname(file_out))
        File.write(file_out, JSON.pretty_generate(project_config))

        Aircana.human_logger.success "Generated project.json at #{file_out}"
        file_out
      end

      private

      def default_template_path
        # We don't use a template for this, generate directly
        nil
      end

      def default_output_path
        File.join(Aircana.configuration.project_dir, ".aircana", "project.json")
      end

      def default_project_config
        {
          "folders" => [],
          "_comment" => [
            "Add folders to include agents from sub-projects",
            "Example:",
            "  'folders': [",
            "    { 'path': 'frontend' },",
            "    { 'path': 'backend' },",
            "    { 'path': 'shared/utils' }",
            "  ]"
          ]
        }
      end
    end
  end
end
