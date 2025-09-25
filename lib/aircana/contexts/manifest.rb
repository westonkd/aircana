# frozen_string_literal: true

require "json"
require "fileutils"

module Aircana
  module Contexts
    class Manifest
      class << self
        def create_manifest(agent, sources)
          validate_sources(sources)

          manifest_path = manifest_path_for(agent)
          manifest_data = build_manifest_data(agent, sources)

          FileUtils.mkdir_p(File.dirname(manifest_path))
          File.write(manifest_path, JSON.pretty_generate(manifest_data))

          Aircana.human_logger.info "Created knowledge manifest for agent '#{agent}'"
          manifest_path
        end

        def update_manifest(agent, sources)
          validate_sources(sources)

          manifest_path = manifest_path_for(agent)

          if File.exist?(manifest_path)
            existing_data = JSON.parse(File.read(manifest_path))
            manifest_data = existing_data.merge({
                                                  "last_updated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
                                                  "sources" => sources
                                                })
          else
            manifest_data = build_manifest_data(agent, sources)
          end

          FileUtils.mkdir_p(File.dirname(manifest_path))
          File.write(manifest_path, JSON.pretty_generate(manifest_data))
          manifest_path
        end

        def read_manifest(agent)
          manifest_path = manifest_path_for(agent)
          return nil unless File.exist?(manifest_path)

          begin
            manifest_data = JSON.parse(File.read(manifest_path))
            validate_manifest(manifest_data)
            manifest_data
          rescue JSON::ParserError => e
            Aircana.human_logger.warn "Invalid manifest for agent '#{agent}': #{e.message}"
            nil
          rescue ManifestError => e
            Aircana.human_logger.warn "Manifest validation failed for agent '#{agent}': #{e.message}"
            nil
          end
        end

        def sources_from_manifest(agent)
          manifest = read_manifest(agent)
          return [] unless manifest

          manifest["sources"] || []
        end

        def manifest_exists?(agent)
          File.exist?(manifest_path_for(agent))
        end

        private

        def manifest_path_for(agent)
          resolved_agent_path = resolve_agent_path(agent)
          File.join(resolved_agent_path, "manifest.json")
        end

        def resolve_agent_path(agent)
          base_path = File.join(Aircana.configuration.agent_knowledge_dir, agent)

          # If this is a symlink (multi-root scenario), resolve to original
          if File.symlink?(base_path)
            File.readlink(base_path)
          else
            base_path
          end
        end

        def build_manifest_data(agent, sources)
          timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

          {
            "version" => "1.0",
            "agent" => agent,
            "created" => timestamp,
            "last_updated" => timestamp,
            "sources" => sources
          }
        end

        def validate_manifest(manifest_data)
          required_fields = %w[version agent sources]

          required_fields.each do |field|
            raise ManifestError, "Missing required field: #{field}" unless manifest_data.key?(field)
          end

          unless manifest_data["version"] == "1.0"
            raise ManifestError, "Unsupported manifest version: #{manifest_data["version"]}"
          end

          validate_sources(manifest_data["sources"])
        end

        def validate_sources(sources)
          raise ManifestError, "Sources must be an array" unless sources.is_a?(Array)

          sources.each do |source|
            validate_source(source)
          end
        end

        def validate_source(source)
          raise ManifestError, "Each source must be a hash" unless source.is_a?(Hash)

          raise ManifestError, "Source missing required field: type" unless source.key?("type")

          case source["type"]
          when "confluence"
            validate_confluence_source(source)
          else
            raise ManifestError, "Unknown source type: #{source["type"]}"
          end
        end

        def validate_confluence_source(source)
          raise ManifestError, "Confluence source missing required field: label" unless source.key?("label")

          return unless source.key?("pages") && !source["pages"].is_a?(Array)

          raise ManifestError, "Confluence pages must be an array"
        end
      end
    end

    class ManifestError < StandardError; end
  end
end
