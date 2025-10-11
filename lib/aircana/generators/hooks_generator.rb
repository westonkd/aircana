# frozen_string_literal: true

require_relative "base_generator"

module Aircana
  module Generators
    class HooksGenerator < BaseGenerator
      # All available hook types (for manual creation)
      ALL_HOOK_TYPES = %w[
        pre_tool_use
        post_tool_use
        user_prompt_submit
        session_start
        refresh_agents
        notification_sqs
        rubocop_pre_commit
        rspec_test
        bundle_install
      ].freeze

      # Default hooks that are auto-installed
      DEFAULT_HOOK_TYPES = %w[
        session_start
        refresh_agents
        notification_sqs
      ].freeze

      class << self
        def available_default_hooks
          DEFAULT_HOOK_TYPES
        end

        def all_available_hooks
          ALL_HOOK_TYPES
        end

        def create_default_hook(hook_name)
          return unless all_available_hooks.include?(hook_name)

          template_path = File.join(File.dirname(__FILE__), "..", "templates", "hooks", "#{hook_name}.erb")
          output_path = File.join(Aircana.configuration.scripts_dir, "#{hook_name}.sh")

          generator = new(file_in: template_path, file_out: output_path)
          generator.generate
        end

        def create_all_default_hooks
          available_default_hooks.each { |hook_name| create_default_hook(hook_name) }
        end
      end

      def initialize(hook_name: nil, **)
        @hook_name = hook_name

        if hook_name
          template_path = File.join(File.dirname(__FILE__), "..", "templates", "hooks", "#{hook_name}.erb")
          output_path = File.join(Aircana.configuration.scripts_dir, "#{hook_name}.sh")
          super(file_in: template_path, file_out: output_path)
        else
          super(**)
        end
      end

      def generate
        result = super
        make_executable if File.exist?(file_out)
        result
      end

      protected

      def locals
        super.merge(
          hook_name: @hook_name,
          project_root: Dir.pwd
        )
      end

      private

      def make_executable
        File.chmod(0o755, file_out)
      end
    end
  end
end
