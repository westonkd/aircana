# frozen_string_literal: true

require "json"
require "fileutils"

module Aircana
  # Manages Claude Code plugin manifest (plugin.json) files
  class PluginManifest
    REQUIRED_FIELDS = %w[name version].freeze
    OPTIONAL_FIELDS = %w[description author homepage repository license keywords].freeze
    ALL_FIELDS = (REQUIRED_FIELDS + OPTIONAL_FIELDS).freeze

    attr_reader :plugin_root

    def initialize(plugin_root)
      @plugin_root = plugin_root
    end

    # Creates a new plugin manifest with the given attributes
    def create(attributes = {})
      validate_required_fields!(attributes)

      manifest_data = build_manifest_data(attributes)
      write_manifest(manifest_data)

      manifest_path
    end

    # Reads the existing plugin manifest
    def read
      return nil unless exists?

      JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError => e
      raise Aircana::Error, "Invalid JSON in plugin manifest: #{e.message}"
    end

    # Updates the plugin manifest with new values
    def update(attributes = {})
      current_data = read || {}
      updated_data = current_data.merge(attributes.transform_keys(&:to_s))

      validate_required_fields!(updated_data)
      write_manifest(updated_data)

      manifest_path
    end

    # Bumps the version number (major, minor, or patch)
    def bump_version(type = :patch)
      current_data = read
      raise Aircana::Error, "No plugin manifest found at #{manifest_path}" unless current_data

      current_version = current_data["version"]
      new_version = bump_semantic_version(current_version, type)

      update("version" => new_version)
      new_version
    end

    # Checks if the plugin manifest exists
    def exists?
      File.exist?(manifest_path)
    end

    # Returns the path to the plugin manifest
    def manifest_path
      File.join(plugin_root, ".claude-plugin", "plugin.json")
    end

    # Returns the directory containing the manifest
    def manifest_dir
      File.join(plugin_root, ".claude-plugin")
    end

    # Validates the current manifest structure
    def validate!
      data = read
      raise Aircana::Error, "No plugin manifest found" unless data

      validate_required_fields!(data)
      validate_version_format!(data["version"])

      true
    end

    private

    def build_manifest_data(attributes)
      data = {
        "name" => attributes[:name] || attributes["name"],
        "version" => attributes[:version] || attributes["version"] || "0.1.0"
      }

      # Add optional fields if provided
      OPTIONAL_FIELDS.each do |field|
        value = attributes[field.to_sym] || attributes[field]
        data[field] = value if value
      end

      data
    end

    def write_manifest(data)
      FileUtils.mkdir_p(manifest_dir)
      File.write(manifest_path, JSON.pretty_generate(data))
    end

    def validate_required_fields!(data)
      REQUIRED_FIELDS.each do |field|
        unless data[field] || data[field.to_sym]
          raise Aircana::Error, "Plugin manifest missing required field: #{field}"
        end
      end
    end

    def validate_version_format!(version)
      return if version.match?(/^\d+\.\d+\.\d+/)

      raise Aircana::Error, "Invalid version format: #{version}. Must be semantic versioning (e.g., 1.0.0)"
    end

    def bump_semantic_version(version, type)
      parts = version.split(".").map(&:to_i)
      raise Aircana::Error, "Invalid version format: #{version}" if parts.size != 3

      case type.to_sym
      when :major
        [parts[0] + 1, 0, 0].join(".")
      when :minor
        [parts[0], parts[1] + 1, 0].join(".")
      when :patch
        [parts[0], parts[1], parts[2] + 1].join(".")
      else
        raise Aircana::Error, "Invalid version bump type: #{type}. Must be major, minor, or patch"
      end
    end

    class << self
      # Creates a default plugin name from a directory path
      def default_plugin_name(directory)
        File.basename(directory).downcase.gsub(/[^a-z0-9]+/, "-")
      end
    end
  end
end
