# frozen_string_literal: true

module Aircana
  class HumanLogger
    # Emoji mappings for different message types
    EMOJIS = {
      # Core status indicators
      success: "✅",
      error: "❌",
      warning: "⚠️",
      info: "ℹ️",

      # Context-specific emojis
      file: "📁",
      files: "📁",
      agent: "🤖",
      network: "🌐",
      page: "📄",
      pages: "📄",
      search: "🔍",
      generation: "⚙️",

      # Action emojis
      created: "📝",
      stored: "💾",
      refresh: "🔄",
      install: "📦",
      found: "🔍",
      added: "➕",
      removed: "➖"
    }.freeze

    # Color codes for terminal output
    COLORS = {
      success: "\e[32m", # Green
      error: "\e[31m",   # Red
      warning: "\e[33m", # Yellow
      info: "\e[36m",    # Cyan
      reset: "\e[0m"     # Reset
    }.freeze

    def initialize(output = $stdout)
      @output = output
    end

    def success(message)
      log_with_emoji_and_color(:success, message)
    end

    def error(message)
      log_with_emoji_and_color(:error, message)
    end

    def warn(message)
      log_with_emoji_and_color(:warning, message)
    end

    def info(message)
      log_with_emoji_and_color(:info, message)
    end

    private

    def log_with_emoji_and_color(level, message)
      emoji = select_emoji(level, message)
      color = COLORS[level]
      reset = COLORS[:reset]

      @output.puts "#{color}#{emoji} #{message}#{reset}"
    end

    def select_emoji(level, message)
      # First check for context-specific emojis based on message content
      context_emoji = detect_context_emoji(message)
      return context_emoji if context_emoji

      # Fall back to level-based emoji
      EMOJIS[level] || EMOJIS[:info]
    end

    def detect_context_emoji(message)
      message_lower = message.downcase

      # Context-based detection first (more specific)
      return EMOJIS[:agent] if message_lower.include?("agent")
      return EMOJIS[:pages] if message_lower.match?(/\d+\s+pages?/)
      return EMOJIS[:page] if message_lower.include?("page")
      return EMOJIS[:files] if message_lower.match?(/\d+\s+files?/) || message_lower.include?("directory")
      return EMOJIS[:file] if message_lower.include?("file") && !message_lower.match?(/\d+\s+files?/)
      if message_lower.include?("http") || message_lower.include?("network") || message_lower.include?("api")
        return EMOJIS[:network]
      end

      # Action-based detection (less specific)
      if message_lower.include?("created") || message_lower.include?("generating") || 
         message_lower.include?("generated")
        return EMOJIS[:created]
      end
      return EMOJIS[:stored] if message_lower.include?("stored") || message_lower.include?("saving")
      return EMOJIS[:refresh] if message_lower.include?("refresh") || message_lower.include?("sync")
      return EMOJIS[:install] if message_lower.include?("install")
      return EMOJIS[:added] if message_lower.include?("added") || message_lower.include?("successfully")
      return EMOJIS[:found] if message_lower.include?("found")

      nil
    end
  end
end
