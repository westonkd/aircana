# frozen_string_literal: true

require_relative "../generators"

module Aircana
  module Generators
    class AskExpertCommandGenerator < BaseGenerator
      def initialize(file_in: nil, file_out: nil)
        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      private

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "commands", "ask_expert.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.output_dir, "commands", "ask-expert.md")
      end
    end
  end
end
