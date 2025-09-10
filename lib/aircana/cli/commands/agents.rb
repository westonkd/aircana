# frozen_string_literal: true

require "tty-prompt"
require_relative "../../generators/agents_generator"
require_relative "../shell_command"

module Aircana
  module CLI
    module Agents
      SUPPORTED_CLAUDE_MODELS = %w[sonnet haiku inherit].freeze
      SUPPORTED_CLAUDE_COLORS = %w[red blue green yellow purple orange pink cyan].freeze

      class << self
        def create
          prompt = TTY::Prompt.new

          agent_name = prompt.ask("Agent name:")
          short_description = prompt.ask("Briefly describe what your agent does:")
          model = prompt.select("Select a model for your agent:", SUPPORTED_CLAUDE_MODELS)
          color = prompt.select("Select a color for your agent:", SUPPORTED_CLAUDE_COLORS)

          description = description_from_claude(short_description)

          file = Generators::AgentsGenerator.new(
            agent_name: normalize_string(agent_name),
            description:,
            short_description:,
            model: normalize_string(model),
            color: normalize_string(color)
          ).generate

          Aircana.logger.info "Agent created at #{file}"
        end

        private

        def normalize_string(string)
          string.strip.downcase.gsub(" ", "-")
        end

        # TODO: Extract into a utility class explicitly for interacting with Claude
        def description_from_claude(description)
          prompt = <<~PROMPT
            Create a concise Claude Code agent description file (without frontmatter)
            for an agent that is described as: #{description}.

            Print the output to STDOUT only, without any additional commentary.
          PROMPT

          ShellCommand.run("claude -p '#{prompt}'")
        end
      end
    end
  end
end
