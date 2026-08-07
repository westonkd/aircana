# frozen_string_literal: true

require "fileutils"

module Aircana
  module Migrations
    module LegacyAgentCleanup
      GENERATED_MARKER = 'Use the skill "'

      class << self
        def run(kb_name)
          path = legacy_agent_path(kb_name)
          return unless generated_by_aircana?(path)

          File.delete(path)
          Aircana.human_logger.info "Removed legacy agent file #{path}"
          remove_legacy_dir_if_empty
        rescue StandardError => e
          Aircana.human_logger.warn "Failed to remove legacy agent file: #{e.message}"
        end

        def legacy_agent_path(kb_name)
          File.join(legacy_agents_dir, "#{kb_name}.md")
        end

        def legacy_agents_dir
          plugin_root = Aircana.configuration.plugin_root

          if Aircana.configuration.plugin_mode?
            File.join(plugin_root, "agents")
          else
            File.join(plugin_root, ".claude", "agents")
          end
        end

        private

        def generated_by_aircana?(path)
          File.file?(path) && File.read(path).include?(GENERATED_MARKER)
        end

        def remove_legacy_dir_if_empty
          dir = legacy_agents_dir
          return unless Dir.exist?(dir) && Dir.empty?(dir)

          Dir.rmdir(dir)
          Aircana.human_logger.info "Removed empty legacy agents directory #{dir}"
        end
      end
    end
  end
end
