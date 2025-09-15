# frozen_string_literal: true

require_relative "generate"
require_relative "install"
require_relative "../../generators/agents_generator"

module Aircana
  module CLI
    module Work
      class << self
        def run
          ensure_worker_agent_installed
          launch_claude_with_worker
        end

        private

        def ensure_worker_agent_installed
          worker_agent_path = File.join(
            Aircana.configuration.claude_code_config_path,
            "agents",
            "worker.md"
          )

          return if File.exist?(worker_agent_path)

          Aircana.human_logger.info("Worker agent not found. Generating and installing...")
          Generate.run
          Install.run
        end

        def launch_claude_with_worker
          prompt = "Start a work session with the 'worker' sub-agent"

          Aircana.human_logger.info("Launching Claude Code with worker agent...")

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

