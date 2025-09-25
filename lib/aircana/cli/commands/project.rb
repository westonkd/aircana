# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "../../symlink_manager"
require_relative "../../generators/project_config_generator"

module Aircana
  module CLI
    module Project
      class << self
        def init
          generator = Aircana::Generators::ProjectConfigGenerator.new
          config_path = generator.generate

          Aircana.human_logger.success "Initialized project.json at #{config_path}"
          Aircana.human_logger.info "Add folders using: aircana project add <path>"
        end

        def add(folder_path)
          project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")

          # Create project.json if it doesn't exist
          init unless File.exist?(project_json_path)

          # Validate folder exists
          full_path = File.join(Aircana.configuration.project_dir, folder_path)
          unless Dir.exist?(full_path)
            Aircana.human_logger.error "Folder not found: #{folder_path}"
            return
          end

          # Load existing config
          config = JSON.parse(File.read(project_json_path))
          config["folders"] ||= []

          # Check if folder already exists
          if config["folders"].any? { |f| f["path"] == folder_path }
            Aircana.human_logger.warn "Folder already configured: #{folder_path}"
            return
          end

          # Add the folder
          config["folders"] << { "path" => folder_path }

          # Save updated config
          File.write(project_json_path, JSON.pretty_generate(config))

          Aircana.human_logger.success "Added folder: #{folder_path}"

          # Check what agents/knowledge would be available
          check_folder_contents(folder_path)

          # Offer to sync
          prompt = TTY::Prompt.new
          sync if prompt.yes?("Would you like to sync symlinks now?")
        end

        def remove(folder_path)
          project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")

          unless File.exist?(project_json_path)
            Aircana.human_logger.error "No project.json found. Run 'aircana project init' first."
            return
          end

          # Load existing config
          config = JSON.parse(File.read(project_json_path))
          config["folders"] ||= []

          # Remove the folder
          original_count = config["folders"].size
          config["folders"].reject! { |f| f["path"] == folder_path }

          if config["folders"].size == original_count
            Aircana.human_logger.warn "Folder not found in configuration: #{folder_path}"
            return
          end

          # Save updated config
          File.write(project_json_path, JSON.pretty_generate(config))

          Aircana.human_logger.success "Removed folder: #{folder_path}"

          # Clean up symlinks
          Aircana::SymlinkManager.cleanup_broken_symlinks
        end

        def list
          project_json_path = File.join(Aircana.configuration.project_dir, ".aircana", "project.json")

          unless File.exist?(project_json_path)
            Aircana.human_logger.info "No project.json found. Run 'aircana project init' to create one."
            return
          end

          config = JSON.parse(File.read(project_json_path))
          folders = config["folders"] || []

          if folders.empty?
            Aircana.human_logger.info "No folders configured."
            Aircana.human_logger.info "Add folders using: aircana project add <path>"
            return
          end

          Aircana.human_logger.info "Configured folders:"
          folders.each do |folder|
            folder_path = folder["path"]
            status = Dir.exist?(File.join(Aircana.configuration.project_dir, folder_path)) ? "✓" : "✗"
            Aircana.human_logger.info "  #{status} #{folder_path}"

            # Show available agents if folder exists
            check_folder_contents(folder_path, indent: "    ") if status == "✓"
          end
        end

        def sync
          Aircana.human_logger.info "Syncing multi-root project symlinks..."

          stats = Aircana::SymlinkManager.sync_multi_root_agents

          if stats[:agents].zero? && stats[:knowledge].zero?
            Aircana.human_logger.info "No agents or knowledge bases to link."
          else
            Aircana.human_logger.success "Sync complete: #{stats[:agents]} agents, #{stats[:knowledge]} knowledge bases"
          end
        end

        private

        def check_folder_contents(folder_path, indent: "  ")
          agents_dir = File.join(folder_path, ".claude", "agents")
          knowledge_dir = File.join(folder_path, ".aircana", "agents")

          agents = []
          knowledge = []

          agents = Dir.glob("#{agents_dir}/*.md").map { |f| File.basename(f, ".md") } if Dir.exist?(agents_dir)

          if Dir.exist?(knowledge_dir)
            knowledge = Dir.glob("#{knowledge_dir}/*").select { |d| File.directory?(d) }
                           .map { |d| File.basename(d) }
          end

          Aircana.human_logger.info "#{indent}Agents: #{agents.join(", ")}" if agents.any?

          Aircana.human_logger.info "#{indent}Knowledge: #{knowledge.join(", ")}" if knowledge.any?

          return unless agents.empty? && knowledge.empty?

          Aircana.human_logger.info "#{indent}No agents or knowledge found"
        end
      end
    end
  end
end
