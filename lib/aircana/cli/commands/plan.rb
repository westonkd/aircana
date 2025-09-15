# frozen_string_literal: true

require_relative "generate"
require_relative "install"
require_relative "../../generators/agents_generator"

module Aircana
  module CLI
    module Plan
      class << self
        def run
          ensure_planner_agent_installed
          launch_claude_with_planner
        end

        private

        def ensure_planner_agent_installed
          planner_agent_path = File.join(
            Aircana.configuration.claude_code_config_path,
            "agents",
            "planner.md"
          )

          return if File.exist?(planner_agent_path)

          Aircana.human_logger.info("Planner agent not found. Generating and installing...")
          Generate.run
          Install.run
        end

        def launch_claude_with_planner
          prompt = "Start a planning session with the 'planner' sub-agent"

          Aircana.human_logger.info("Launching Claude Code with planner agent...")

          claude_path = find_claude_path
          if claude_path
            system("#{claude_path} \"#{prompt}\"")
          else
            handle_claude_not_found(prompt)
          end
        end

        def handle_claude_not_found(prompt)
          error_message = "Claude Code command not found. " \
                          "Please make sure Claude Code is installed and in your PATH."
          Aircana.human_logger.error(error_message)
          Aircana.human_logger.info("You can manually start Claude Code and run: #{prompt}")
        end

        def find_claude_path
          # Try common locations for Claude Code binary (same as ClaudeClient)
          possible_paths = [
            File.expand_path("~/.claude/local/claude"),
            `/usr/bin/which claude`.strip,
            "/usr/local/bin/claude"
          ]

          possible_paths.each do |path|
            return path if !path.empty? && File.executable?(path)
          end

          nil
        end
      end
    end
  end
end
