# frozen_string_literal: true

require "json"
require "fileutils"

module Aircana
  # Manages Claude Code plugin hooks manifest (hooks/hooks.json) files
  class HooksManifest
    VALID_EVENTS = %w[PreToolUse PostToolUse UserPromptSubmit SessionStart Notification].freeze
    VALID_HOOK_TYPES = %w[command validation notification].freeze

    attr_reader :plugin_root

    def initialize(plugin_root)
      @plugin_root = plugin_root
    end

    # Creates a new hooks manifest with the given hooks configuration
    def create(hooks_config = {})
      validate_hooks_config!(hooks_config)
      write_manifest(hooks_config)

      manifest_path
    end

    # Reads the existing hooks manifest
    def read
      return nil unless exists?

      JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError => e
      raise Aircana::Error, "Invalid JSON in hooks manifest: #{e.message}"
    end

    # Updates the hooks manifest with new values
    def update(hooks_config = {})
      current_data = read || {}
      updated_data = deep_merge(current_data, hooks_config)

      validate_hooks_config!(updated_data)
      write_manifest(updated_data)

      manifest_path
    end

    # Adds a hook to the manifest
    def add_hook(event:, hook_entry:, matcher: nil)
      validate_event!(event)
      validate_hook_entry!(hook_entry)

      current_data = read || {}
      current_data[event] ||= []

      hook_config = build_hook_config(hook_entry, matcher)
      current_data[event] << hook_config

      write_manifest(current_data)
      manifest_path
    end

    # Removes a hook from the manifest
    def remove_hook(event:, command:)
      current_data = read
      return manifest_path unless current_data && current_data[event]

      current_data[event].reject! do |hook_group|
        hook_group["hooks"]&.any? { |h| h["command"] == command }
      end

      current_data.delete(event) if current_data[event].empty?

      write_manifest(current_data)
      manifest_path
    end

    # Checks if the hooks manifest exists
    def exists?
      File.exist?(manifest_path)
    end

    # Returns the path to the hooks manifest
    def manifest_path
      File.join(plugin_root, "hooks", "hooks.json")
    end

    # Returns the hooks directory
    def hooks_dir
      File.join(plugin_root, "hooks")
    end

    # Validates the current manifest structure
    def validate!
      data = read
      return true unless data # Empty manifest is valid

      validate_hooks_config!(data)
      true
    end

    # Converts old settings.local.json hook format to hooks.json format
    def self.from_settings_format(settings_hooks)
      hooks_config = {}

      settings_hooks.each do |event, hook_groups|
        hooks_config[event] = hook_groups.map do |group|
          {
            "hooks" => group["hooks"],
            "matcher" => group["matcher"]
          }.compact
        end
      end

      hooks_config
    end

    private

    def build_hook_config(hook_entry, matcher)
      config = {
        "hooks" => [hook_entry]
      }
      config["matcher"] = matcher if matcher
      config
    end

    def write_manifest(data)
      FileUtils.mkdir_p(hooks_dir)
      File.write(manifest_path, JSON.pretty_generate(data))
    end

    def validate_hooks_config!(config)
      return if config.nil? || config.empty?

      config.each do |event, hook_groups|
        validate_event!(event)

        raise Aircana::Error, "Hook configuration for #{event} must be an array" unless hook_groups.is_a?(Array)

        hook_groups.each do |group|
          validate_hook_group!(group)
        end
      end
    end

    def validate_event!(event)
      return if VALID_EVENTS.include?(event)

      raise Aircana::Error, "Invalid hook event: #{event}. Must be one of: #{VALID_EVENTS.join(", ")}"
    end

    def validate_hook_group!(group)
      raise Aircana::Error, "Hook group must be a hash with 'hooks' array" unless group.is_a?(Hash) && group["hooks"]

      raise Aircana::Error, "Hook group 'hooks' must be an array" unless group["hooks"].is_a?(Array)

      group["hooks"].each do |hook|
        validate_hook_entry!(hook)
      end
    end

    def validate_hook_entry!(hook)
      raise Aircana::Error, "Hook entry must be a hash" unless hook.is_a?(Hash)

      unless hook["type"] && VALID_HOOK_TYPES.include?(hook["type"])
        raise Aircana::Error, "Hook must have a valid type: #{VALID_HOOK_TYPES.join(", ")}"
      end

      return if hook["command"]

      raise Aircana::Error, "Hook must have a command"
    end

    def deep_merge(hash1, hash2)
      result = hash1.dup

      hash2.each do |key, value|
        result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
                        deep_merge(result[key], value)
                      elsif result[key].is_a?(Array) && value.is_a?(Array)
                        result[key] + value
                      else
                        value
                      end
      end

      result
    end
  end
end
