# frozen_string_literal: true

require "json"
require "fileutils"

module Aircana
  class SymlinkManager
    class << self
      def sync_multi_root_agents
        project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")

        unless File.exist?(project_json_path)
          Aircana.human_logger.info "No project.json found, skipping multi-root sync"
          return { agents: 0, knowledge: 0 }
        end

        begin
          config = JSON.parse(File.read(project_json_path))
          folders = config["folders"] || []

          if folders.empty?
            Aircana.human_logger.info "No folders configured in project.json"
            return { agents: 0, knowledge: 0 }
          end

          cleanup_broken_symlinks
          create_symlinks_for_folders(folders)
        rescue JSON::ParserError => e
          Aircana.human_logger.error "Invalid JSON in project.json: #{e.message}"
          { agents: 0, knowledge: 0 }
        end
      end

      def cleanup_broken_symlinks
        claude_agents_dir = File.join(Aircana.configuration.project_dir, ".claude", "agents")
        aircana_agents_dir = File.join(Aircana.configuration.project_dir, ".aircana", "agents")

        [claude_agents_dir, aircana_agents_dir].each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob("#{dir}/*").each do |path|
            if File.symlink?(path) && !File.exist?(path)
              File.delete(path)
              Aircana.human_logger.info "Removed broken symlink: #{path}"
            end
          end
        end
      end

      def create_symlinks_for_folders(folders)
        stats = { agents: 0, knowledge: 0 }

        folders.each do |folder_config|
          folder_path = folder_config["path"]
          next unless folder_path_valid?(folder_path)

          prefix = folder_path.tr("/", "_")

          stats[:agents] += link_agents(folder_path, prefix)
          stats[:knowledge] += link_knowledge(folder_path, prefix)
        end

        Aircana.human_logger.success "Linked #{stats[:agents]} agents and #{stats[:knowledge]} knowledge bases"
        stats
      end

      def link_agents(folder_path, prefix)
        source_dir = File.join(folder_path, ".claude", "agents")
        target_dir = File.join(Aircana.configuration.project_dir, ".claude", "agents")

        return 0 unless Dir.exist?(source_dir)

        FileUtils.mkdir_p(target_dir)
        linked = 0

        Dir.glob("#{source_dir}/*.md").each do |agent_file|
          agent_name = File.basename(agent_file, ".md")
          link_name = "#{prefix}_#{agent_name}.md"
          target_path = File.join(target_dir, link_name)

          # Use relative paths for symlinks
          relative_path = calculate_relative_path(target_dir, agent_file)

          File.symlink(relative_path, target_path) unless File.exist?(target_path)
          linked += 1
          Aircana.human_logger.info "Linked agent: #{link_name}"
        end

        linked
      end

      def link_knowledge(folder_path, prefix)
        source_dir = File.join(folder_path, ".aircana", "agents")
        target_dir = File.join(Aircana.configuration.project_dir, ".aircana", "agents")

        return 0 unless Dir.exist?(source_dir)

        FileUtils.mkdir_p(target_dir)
        linked = 0

        Dir.glob("#{source_dir}/*").each do |agent_dir|
          next unless File.directory?(agent_dir)

          agent_name = File.basename(agent_dir)
          link_name = "#{prefix}_#{agent_name}"
          target_path = File.join(target_dir, link_name)

          # Use relative paths for symlinks
          relative_path = calculate_relative_path(target_dir, agent_dir)

          File.symlink(relative_path, target_path) unless File.exist?(target_path)
          linked += 1
          Aircana.human_logger.info "Linked knowledge: #{link_name}"
        end

        linked
      end

      def folder_path_valid?(folder_path)
        full_path = File.join(Aircana.configuration.project_dir, folder_path)

        unless Dir.exist?(full_path)
          Aircana.human_logger.warn "Folder not found: #{folder_path}"
          return false
        end

        true
      end

      def calculate_relative_path(from_dir, to_path)
        # Calculate the relative path from one directory to another
        from = Pathname.new(File.expand_path(from_dir))
        to = Pathname.new(File.expand_path(to_path))
        to.relative_path_from(from).to_s
      end

      # Helper methods for resolving symlinked agent paths
      def resolve_agent_path(agent_name)
        agent_path = File.join(Aircana.configuration.agent_knowledge_dir, agent_name)

        if File.symlink?(agent_path)
          File.readlink(agent_path)
        else
          agent_path
        end
      end

      def agent_is_symlinked?(agent_name)
        agent_path = File.join(Aircana.configuration.agent_knowledge_dir, agent_name)
        File.symlink?(agent_path)
      end

      def resolve_symlinked_path(path)
        File.symlink?(path) ? File.readlink(path) : path
      end
    end
  end
end
