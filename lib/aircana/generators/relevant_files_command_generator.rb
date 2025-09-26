# frozen_string_literal: true

require_relative "../generators"

module Aircana
  module Generators
    class RelevantFilesCommandGenerator < BaseGenerator
      def initialize(file_in: nil, file_out: nil)
        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      protected

      def locals
        super.merge({ relevant_project_files_path: })
      end

      private

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "commands", "add_relevant_files.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.output_dir, "commands", "air-add-relevant-files.md")
      end

      def relevant_project_files_path
        File.join(Aircana.configuration.relevant_project_files_dir, "relevant_files.md")
      end
    end
  end
end
