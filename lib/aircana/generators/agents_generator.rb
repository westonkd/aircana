# frozen_string_literal: true

require_relative "../generators"
require_relative "../contexts/manifest"

module Aircana
  module Generators
    class AgentsGenerator < BaseGenerator
      PRESET_COLORS = %w[red blue green cyan yellow magenta purple pink teal orange].freeze

      attr_reader :kb_name, :agent_name, :agent_description, :skill_name, :color

      def initialize(kb_name:, agent_description: nil, color: nil, file_in: nil, file_out: nil)
        @kb_name = kb_name
        @agent_name = kb_name
        @agent_description = agent_description || generate_agent_description
        @skill_name = generate_skill_name
        @color = color || PRESET_COLORS.sample

        super(
          file_in: file_in || default_template_path,
          file_out: file_out || default_output_path
        )
      end

      # Generate agent markdown from manifest data
      def self.from_manifest(kb_name)
        manifest = Contexts::Manifest.read_manifest(kb_name)
        raise Error, "No manifest found for knowledge base '#{kb_name}'" unless manifest

        # Use the same description generation as skills
        agent_description = generate_agent_description_from_manifest(manifest, kb_name)

        new(
          kb_name: kb_name,
          agent_description: agent_description
        )
      end

      def self.generate_agent_description_from_manifest(manifest, kb_name)
        # Same description as skill - optimized for Claude's agent discovery
        source_count = manifest["sources"]&.size || 0
        "Discover critical context for #{kb_name.split("-").join(" ")} from #{source_count} knowledge sources"
      end

      protected

      def locals
        super.merge({
                      kb_name:,
                      agent_name:,
                      agent_description:,
                      skill_name:,
                      color:
                    })
      end

      private

      def default_template_path
        File.join(File.dirname(__FILE__), "..", "templates", "agents", "base_agent.erb")
      end

      def default_output_path
        File.join(Aircana.configuration.agents_dir, "#{kb_name}.md")
      end

      def generate_agent_description
        "Discover critical context for #{kb_name.split("-").join(" ")}"
      end

      def generate_skill_name
        # Convert kb_name to skill name format: "Learn Canvas Backend Sharding"
        "Learn #{kb_name.split("-").map(&:capitalize).join(" ")}"
      end
    end
  end
end
