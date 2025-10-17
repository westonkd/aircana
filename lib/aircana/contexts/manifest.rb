# frozen_string_literal: true

require "json"
require "fileutils"

module Aircana
  module Contexts
    class Manifest
      class << self
        def create_manifest(kb_name, sources, kb_type: "local")
          validate_sources(sources)
          validate_kb_type(kb_type)

          manifest_path = manifest_path_for(kb_name)
          manifest_data = build_manifest_data(kb_name, sources, kb_type)

          FileUtils.mkdir_p(File.dirname(manifest_path))
          File.write(manifest_path, JSON.pretty_generate(manifest_data))

          Aircana.human_logger.info "Created knowledge manifest for '#{kb_name}' (kb_type: #{kb_type})"
          manifest_path
        end

        def update_manifest(kb_name, sources, kb_type: nil)
          validate_sources(sources)

          manifest_path = manifest_path_for(kb_name)

          if File.exist?(manifest_path)
            existing_data = JSON.parse(File.read(manifest_path))
            # Preserve existing kb_type unless explicitly provided
            kb_type_to_use = kb_type || existing_data["kb_type"] || "local"
            manifest_data = existing_data.merge({ "sources" => sources, "kb_type" => kb_type_to_use })
          else
            kb_type_to_use = kb_type || "local"
            manifest_data = build_manifest_data(kb_name, sources, kb_type_to_use)
          end

          validate_kb_type(manifest_data["kb_type"])
          FileUtils.mkdir_p(File.dirname(manifest_path))
          File.write(manifest_path, JSON.pretty_generate(manifest_data))
          manifest_path
        end

        def read_manifest(kb_name)
          manifest_path = manifest_path_for(kb_name)
          return nil unless File.exist?(manifest_path)

          begin
            manifest_data = JSON.parse(File.read(manifest_path))
            validate_manifest(manifest_data)
            manifest_data
          rescue JSON::ParserError => e
            Aircana.human_logger.warn "Invalid manifest for KB '#{kb_name}': #{e.message}"
            nil
          rescue ManifestError => e
            Aircana.human_logger.warn "Manifest validation failed for KB '#{kb_name}': #{e.message}"
            nil
          end
        end

        def sources_from_manifest(kb_name)
          manifest = read_manifest(kb_name)
          return [] unless manifest

          manifest["sources"] || []
        end

        def kb_type_from_manifest(kb_name)
          manifest = read_manifest(kb_name)
          return "local" unless manifest

          manifest["kb_type"] || "local"
        end

        def manifest_exists?(kb_name)
          File.exist?(manifest_path_for(kb_name))
        end

        private

        def manifest_path_for(kb_name)
          resolved_kb_path = resolve_kb_path(kb_name)
          File.join(resolved_kb_path, "manifest.json")
        end

        def resolve_kb_path(kb_name)
          File.join(Aircana.configuration.kb_knowledge_dir, kb_name)
        end

        def build_manifest_data(kb_name, sources, kb_type = "local")
          {
            "version" => "1.0",
            "name" => kb_name,
            "kb_type" => kb_type,
            "sources" => sources
          }
        end

        def validate_manifest(manifest_data)
          required_fields = %w[version name sources]

          required_fields.each do |field|
            raise ManifestError, "Missing required field: #{field}" unless manifest_data.key?(field)
          end

          unless manifest_data["version"] == "1.0"
            raise ManifestError, "Unsupported manifest version: #{manifest_data["version"]}"
          end

          # kb_type is optional for backward compatibility, defaults to "local"
          kb_type = manifest_data["kb_type"] || "local"
          validate_kb_type(kb_type)

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
          when "web"
            validate_web_source(source)
          else
            raise ManifestError, "Unknown source type: #{source["type"]}"
          end
        end

        def validate_confluence_source(source)
          raise ManifestError, "Confluence source missing required field: pages" unless source.key?("pages")

          raise ManifestError, "Confluence pages must be an array" unless source["pages"].is_a?(Array)

          source["pages"].each do |page_entry|
            validate_confluence_page_entry(page_entry)
          end
        end

        def validate_confluence_page_entry(page_entry)
          raise ManifestError, "Each page entry must be a hash" unless page_entry.is_a?(Hash)

          raise ManifestError, "Page entry missing required field: id" unless page_entry.key?("id")

          raise ManifestError, "Page entry missing required field: summary" unless page_entry.key?("summary")
        end

        def validate_web_source(source)
          raise ManifestError, "Web source missing required field: urls" unless source.key?("urls")

          raise ManifestError, "Web urls must be an array" unless source["urls"].is_a?(Array)

          source["urls"].each do |url_entry|
            validate_web_url_entry(url_entry)
          end
        end

        def validate_web_url_entry(url_entry)
          raise ManifestError, "Each URL entry must be a hash" unless url_entry.is_a?(Hash)

          raise ManifestError, "URL entry missing required field: url" unless url_entry.key?("url")

          raise ManifestError, "URL entry missing required field: summary" unless url_entry.key?("summary")
        end

        def validate_kb_type(kb_type)
          valid_types = %w[remote local]
          return if valid_types.include?(kb_type)

          raise ManifestError, "Invalid kb_type: #{kb_type}. Must be one of: #{valid_types.join(", ")}"
        end
      end
    end

    class ManifestError < StandardError; end
  end
end
