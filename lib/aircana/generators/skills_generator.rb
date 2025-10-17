# frozen_string_literal: true

require_relative "../generators"
require_relative "../contexts/manifest"

module Aircana
  module Generators
    class SkillsGenerator < BaseGenerator
      attr_reader :kb_name, :short_description, :skill_description, :knowledge_files

      # rubocop:disable Metrics/ParameterLists
      def initialize(kb_name:, short_description: nil, skill_description: nil, knowledge_files: [], file_in: nil,
                     file_out: nil)
        @kb_name = kb_name
        @short_description = short_description
        @skill_description = skill_description || generate_skill_description
        @knowledge_files = knowledge_files

        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end
      # rubocop:enable Metrics/ParameterLists

      # Generate SKILL.md based on manifest data
      def self.from_manifest(kb_name)
        manifest = Contexts::Manifest.read_manifest(kb_name)
        raise Error, "No manifest found for knowledge base '#{kb_name}'" unless manifest

        knowledge_files = extract_knowledge_files_from_manifest(manifest)
        skill_description = generate_skill_description_from_manifest(manifest, kb_name)

        new(
          kb_name: kb_name,
          skill_description: skill_description,
          knowledge_files: knowledge_files
        )
      end

      # Class methods for manifest processing
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      # rubocop:disable Metrics/PerceivedComplexity
      def self.extract_knowledge_files_from_manifest(manifest)
        files = []

        manifest["sources"]&.each do |source|
          case source["type"]
          when "confluence"
            source["pages"]&.each do |page|
              files << {
                summary: page["summary"] || "Documentation",
                filename: "#{sanitize_filename_from_id(page["id"])}.md"
              }
            end
          when "web"
            source["urls"]&.each do |url_entry|
              files << {
                summary: url_entry["summary"] || "Web resource",
                filename: "#{sanitize_filename_from_url(url_entry["url"])}.md"
              }
            end
          end
        end

        files
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def self.generate_skill_description_from_manifest(manifest, kb_name)
        # Generate a description optimized for Claude's skill discovery
        source_count = manifest["sources"]&.size || 0
        "Discover critical context for #{kb_name.split("-").join(" ")} from #{source_count} knowledge sources"
      end

      def self.sanitize_filename_from_id(page_id)
        "page_#{page_id}"
      end

      def self.sanitize_filename_from_url(url)
        # Extract meaningful name from URL
        uri = URI.parse(url)
        path_segments = uri.path.split("/").reject(&:empty?)

        if path_segments.any?
          path_segments.last.gsub(/[^a-z0-9\-_]/i, "-").gsub(/-+/, "-").downcase
        else
          uri.host.gsub(/[^a-z0-9\-_]/i, "-").gsub(/-+/, "-").downcase
        end
      rescue URI::InvalidURIError
        "web_resource"
      end

      protected

      def locals
        super.merge({
                      kb_name:,
                      skill_description:,
                      knowledge_files:
                    })
      end

      private

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "skills", "base_skill.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.skills_dir, kb_name, "SKILL.md")
      end

      def generate_skill_description
        return @skill_description if @skill_description

        if @short_description
          "Discover critical context for #{short_description}"
        else
          "Discover critical context for #{kb_name.split("-").join(" ")}"
        end
      end
    end
  end
end
