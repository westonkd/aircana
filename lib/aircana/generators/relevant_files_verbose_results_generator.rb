# frozen_string_literal: true

require_relative "../generators"

module Aircana
  module Generators
    class RelevantFilesVerboseResultsGenerator < BaseGenerator
      def initialize(file_in: nil, file_out: nil)
        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      private

      def locals
        super.merge({ relevant_files: })
      end

      def relevant_files
        Dir.glob("#{Aircana.configuration.relevant_project_files_dir}/*")
      end

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "relevant_files_verbose_results.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.relevant_project_files_dir, "relevant_files.md")
      end
    end
  end
end
