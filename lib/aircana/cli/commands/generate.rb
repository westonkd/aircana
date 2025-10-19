# frozen_string_literal: true

# Commands that reference old agent system - commented out for now
# require_relative "../../generators/plan_command_generator"
# require_relative "../../generators/record_command_generator"
# require_relative "../../generators/execute_command_generator"
# require_relative "../../generators/review_command_generator"
# require_relative "../../generators/apply_feedback_command_generator"
# require_relative "../../generators/ask_expert_command_generator"
require_relative "../../generators/hooks_generator"

module Aircana
  module CLI
    module Generate
      class << self
        def generators
          # No default commands for now - they referenced the old agent system
          @generators ||= []

          # TODO: Re-enable these when we have a new command system
          # @generators ||= [
          #   Aircana::Generators::PlanCommandGenerator.new,
          #   Aircana::Generators::RecordCommandGenerator.new,
          #   Aircana::Generators::ExecuteCommandGenerator.new,
          #   Aircana::Generators::ReviewCommandGenerator.new,
          #   Aircana::Generators::ApplyFeedbackCommandGenerator.new,
          #   Aircana::Generators::AskExpertCommandGenerator.new
          # ]
        end

        def run
          clean_output_directories
          generators.each(&:generate)
          generate_default_hooks
          Aircana.human_logger.success("Re-generated #{Aircana.configuration.output_dir} files.")
        end

        private

        def clean_output_directories
          # Remove stale command files to prevent duplicates during init
          commands_dir = File.join(Aircana.configuration.output_dir, "commands")
          FileUtils.rm_rf(Dir.glob("#{commands_dir}/*")) if Dir.exist?(commands_dir)
        end

        def generate_default_hooks
          Aircana::Generators::HooksGenerator.available_default_hooks.each do |hook_name|
            Aircana::Generators::HooksGenerator.create_default_hook(hook_name)
          end
        end
      end
    end
  end
end
