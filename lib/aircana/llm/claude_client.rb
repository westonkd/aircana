# frozen_string_literal: true

require "English"
require_relative "base"

module Aircana
  module LLM
    class ClaudeClient < Base
      def prompt(text)
        start_spinner("Generating response with Claude...")

        begin
          result = execute_claude_command(text)
          success_spinner("Generated response with Claude")
          result.strip
        rescue StandardError => e
          error_spinner("Failed to generate response: #{e.message}")
          raise Error, "Claude request failed: #{e.message}"
        end
      end

      private

      def execute_claude_command(text)
        command = build_claude_command(text)
        execute_system_command(command)
      end

      def execute_system_command(command)
        result = `#{command}`

        unless $CHILD_STATUS.success?
          raise StandardError,
                "Claude command failed with exit code #{$CHILD_STATUS.exitstatus}"
        end

        result
      end

      def build_claude_command(text)
        escaped_text = text.gsub("'", "'\"'\"'")
        claude_path = find_claude_path
        "#{claude_path} -p '#{escaped_text}'"
      end

      def find_claude_path
        # Try common locations for Claude Code binary
        possible_paths = [
          File.expand_path("~/.claude/local/claude"),
          `which claude`.strip,
          "/usr/local/bin/claude"
        ]

        possible_paths.each do |path|
          return path if !path.empty? && File.executable?(path)
        end

        # Fallback to just 'claude' and hope it's in PATH
        "claude"
      end
    end
  end
end
