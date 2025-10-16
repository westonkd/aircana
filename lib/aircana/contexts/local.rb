# frozen_string_literal: true

require "fileutils"

module Aircana
  module Contexts
    class Local
      def store_content(title:, content:, agent:, kb_type: "remote")
        agent_dir = create_agent_knowledge_dir(agent, kb_type)
        filename = sanitize_filename(title)
        filepath = File.join(agent_dir, "#{filename}.md")

        File.write(filepath, content)
        Aircana.human_logger.success "Stored '#{title}' for agent '#{agent}' at #{filepath}"

        filepath
      end

      private

      def create_agent_knowledge_dir(agent, kb_type = "remote")
        config = Aircana.configuration
        # Route to appropriate directory based on kb_type
        agent_dir = config.agent_knowledge_path(agent, kb_type)

        FileUtils.mkdir_p(agent_dir)

        agent_dir
      end

      def sanitize_filename(title)
        # Replace invalid characters with safe alternatives
        # Remove or replace characters that are problematic in filenames
        sanitized = title.strip
                         .gsub(%r{[<>:"/\\|?*]}, "-") # Replace invalid chars with hyphens
                         .gsub(/\s+/, "-")             # Replace spaces with hyphens
                         .gsub(/-+/, "-")              # Collapse multiple hyphens
                         .gsub(/^-|-$/, "")            # Remove leading/trailing hyphens

        # Ensure the filename isn't empty and isn't too long
        sanitized = "untitled" if sanitized.empty?
        sanitized = sanitized[0, 200] if sanitized.length > 200 # Limit to 200 chars

        sanitized
      end
    end
  end
end
