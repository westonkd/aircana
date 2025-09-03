# frozen_string_literal: true

require_relative "./generate"

module Aircana
  module CLI
    module Install
      class << self
        def run
          # See if the output directory exists. If not, warn and return.
          unless Dir.exist?(Aircana.configuration.output_dir)
            Aircana.logger.warn("No generated output files-auto generating now...")

            Generate.run
          end

          claude_commands_dir = File.join(Aircana.configuration.claude_code_config_path, "commands")
          Aircana.create_dir_if_needed(claude_commands_dir)

          Dir.glob("#{Aircana.configuration.output_dir}/commands/*").each do |file|
            Aircana.logger.info("Installing #{file} to #{claude_commands_dir}")
            FileUtils.cp(file, claude_commands_dir)
          end
        end
      end
    end
  end
end
