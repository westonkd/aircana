# frozen_string_literal: true

require "tty-spinner"

module Aircana
  module LLM
    class Base
      def initialize
        @spinner = nil
      end

      def prompt(text)
        raise NotImplementedError, "Subclasses must implement #prompt"
      end

      protected

      def truncate_content(content, max_length = 2000)
        return content if content.length <= max_length

        "#{content[0..max_length]}..."
      end

      def start_spinner(message)
        @spinner = TTY::Spinner.new("[:spinner] #{message}", format: :dots)
        @spinner.auto_spin
      end

      def success_spinner(message)
        return unless @spinner

        @spinner.stop("✓")
        puts message
      end

      def error_spinner(message)
        return unless @spinner

        @spinner.stop("✗")
        puts message
      end
    end
  end
end
