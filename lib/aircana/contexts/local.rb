# frozen_string_literal: true

require "fileutils"

module Aircana
  module Contexts
    class Local
      def store_content(title:, content:, kb_name:, kb_type: "local") # rubocop:disable Lint/UnusedMethodArgument
        kb_dir = create_kb_dir(kb_name)
        filename = sanitize_filename(title)
        filepath = File.join(kb_dir, "#{filename}.md")

        File.write(filepath, content)
        Aircana.human_logger.success "Stored '#{title}' for KB '#{kb_name}' at #{filepath}"

        filepath
      end

      private

      def create_kb_dir(kb_name)
        config = Aircana.configuration
        kb_dir = config.kb_knowledge_path(kb_name)

        FileUtils.mkdir_p(kb_dir)

        kb_dir
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
