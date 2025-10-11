# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "../../plugin_manifest"

module Aircana
  module CLI
    module Plugin # rubocop:disable Metrics/ModuleLength
      class << self
        def info # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          ensure_plugin_exists!

          manifest = PluginManifest.new(Aircana.configuration.plugin_root)
          data = manifest.read

          Aircana.human_logger.info("Plugin Information:")
          Aircana.human_logger.info("  Name: #{data["name"]}")
          Aircana.human_logger.info("  Version: #{data["version"]}")
          Aircana.human_logger.info("  Description: #{data["description"]}") if data["description"]

          # Display author information
          if data["author"]
            if data["author"].is_a?(Hash)
              Aircana.human_logger.info("  Author: #{data["author"]["name"]}")
              Aircana.human_logger.info("    Email: #{data["author"]["email"]}") if data["author"]["email"]
              Aircana.human_logger.info("    URL: #{data["author"]["url"]}") if data["author"]["url"]
            else
              Aircana.human_logger.info("  Author: #{data["author"]}")
            end
          end

          Aircana.human_logger.info("  License: #{data["license"]}") if data["license"]
          Aircana.human_logger.info("  Homepage: #{data["homepage"]}") if data["homepage"]
          Aircana.human_logger.info("  Repository: #{data["repository"]}") if data["repository"]

          Aircana.human_logger.info("  Keywords: #{data["keywords"].join(", ")}") if data["keywords"]&.any?

          Aircana.human_logger.info("\nManifest location: #{manifest.manifest_path}")
        end

        def update # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          ensure_plugin_exists!

          manifest = PluginManifest.new(Aircana.configuration.plugin_root)
          current_data = manifest.read

          prompt = TTY::Prompt.new

          # Build update hash with only fields that user wants to change
          updates = {}

          # Handle regular fields
          field_prompts = {
            "description" => "Description",
            "homepage" => "Homepage URL",
            "repository" => "Repository URL",
            "license" => "License"
          }

          field_prompts.each do |field, label|
            current = current_data[field]
            value = prompt.ask("#{label}:", default: current)
            updates[field] = value if value != current
          end

          # Handle author separately (object)
          if prompt.yes?("Update author information?", default: false)
            current_author = current_data["author"] || {}
            current_author = {} unless current_author.is_a?(Hash)

            author = {}
            author_name = prompt.ask("Author name:", default: current_author["name"])
            author["name"] = author_name if author_name && !author_name.empty?

            author_email = prompt.ask("Author email:", default: current_author["email"])
            author["email"] = author_email if author_email && !author_email.empty?

            author_url = prompt.ask("Author URL:", default: current_author["url"])
            author["url"] = author_url if author_url && !author_url.empty?

            updates["author"] = author unless author.empty?
          end

          # Handle keywords separately (array)
          if prompt.yes?("Update keywords?", default: false)
            current_keywords = (current_data["keywords"] || []).join(", ")
            keywords_input = prompt.ask("Keywords (comma-separated):", default: current_keywords)
            updates["keywords"] = keywords_input.split(",").map(&:strip) if keywords_input
          end

          if updates.empty?
            Aircana.human_logger.info("No changes made.")
            return
          end

          manifest.update(updates)
          Aircana.human_logger.success("Plugin manifest updated successfully!")
        end

        def version(action = nil, bump_type = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          ensure_plugin_exists!

          manifest = PluginManifest.new(Aircana.configuration.plugin_root)

          case action
          when "bump"
            type = bump_type&.to_sym || :patch
            new_version = manifest.bump_version(type)
            Aircana.human_logger.success("Version bumped to #{new_version}")
          when "set"
            prompt = TTY::Prompt.new
            new_version = prompt.ask("New version:")
            manifest.update("version" => new_version)
            Aircana.human_logger.success("Version set to #{new_version}")
          else
            data = manifest.read
            Aircana.human_logger.info("Current version: #{data["version"]}")
          end
        end

        def validate # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          Aircana.human_logger.info("Validating plugin structure...")

          errors = []

          # Check plugin manifest
          manifest = PluginManifest.new(Aircana.configuration.plugin_root)
          if manifest.exists?
            begin
              manifest.validate!
              Aircana.human_logger.success("✓ Plugin manifest is valid")
            rescue Aircana::Error => e
              errors << "Plugin manifest validation failed: #{e.message}"
            end
          else
            errors << "Plugin manifest not found at #{manifest.manifest_path}"
          end

          # Check directory structure
          %w[agents commands hooks].each do |dir|
            dir_path = File.join(Aircana.configuration.plugin_root, dir)
            if Dir.exist?(dir_path)
              Aircana.human_logger.success("✓ Directory exists: #{dir}/")
            else
              errors << "Missing directory: #{dir}/"
            end
          end

          # Check hooks manifest if hooks directory exists
          if Dir.exist?(Aircana.configuration.hooks_dir)
            hooks_manifest = HooksManifest.new(Aircana.configuration.plugin_root)
            if hooks_manifest.exists?
              begin
                hooks_manifest.validate!
                Aircana.human_logger.success("✓ Hooks manifest is valid")
              rescue Aircana::Error => e
                errors << "Hooks manifest validation failed: #{e.message}"
              end
            end
          end

          # Summary
          if errors.empty?
            Aircana.human_logger.success("\nPlugin validation passed! ✓")
          else
            Aircana.human_logger.error("\nValidation failed with #{errors.size} error(s):")
            errors.each { |error| Aircana.human_logger.error("  - #{error}") }
            exit 1
          end
        end

        private

        def ensure_plugin_exists!
          manifest = PluginManifest.new(Aircana.configuration.plugin_root)
          return if manifest.exists?

          Aircana.human_logger.error("No plugin found in current directory.")
          Aircana.human_logger.info("Run 'aircana init' to create a new plugin.")
          exit 1
        end
      end
    end
  end
end
