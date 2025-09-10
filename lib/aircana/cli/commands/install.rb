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
          claude_commands_dir = File.join(Aircana.configuration.claude_code_config_path, "commands")
          Aircana.create_dir_if_needed(claude_commands_dir)

          copy_command_files(claude_commands_dir)
        end

        def copy_command_files(destination_dir)
          Dir.glob("#{Aircana.configuration.output_dir}/commands/*").each do |file|
            Aircana.human_logger.success("Installing #{file} to #{destination_dir}")
            FileUtils.cp(file, destination_dir)
          end
        end
      end
    end
  end
end
