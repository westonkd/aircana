# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "../../generators/hooks_generator"
require_relative "install"

module Aircana
  module CLI
    module Hooks
      class << self
        def list
          available_hooks = Aircana::Generators::HooksGenerator.available_default_hooks
          installed_hooks_list = installed_hooks

          if available_hooks.empty?
            Aircana.human_logger.info "No hooks available."
            return
          end

          Aircana.human_logger.info "Available Hooks:"
          available_hooks.each do |hook_name|
            status = installed_hooks_list.include?(hook_name) ? "[INSTALLED]" : "[AVAILABLE]"
            description = hook_description(hook_name)
            Aircana.human_logger.info "  #{status} #{hook_name} - #{description}"
          end
        end

        def enable(hook_name)
          unless Aircana::Generators::HooksGenerator.available_default_hooks.include?(hook_name)
            Aircana.human_logger.error "Hook '#{hook_name}' is not available."
            available_hooks_list = Aircana::Generators::HooksGenerator.available_default_hooks.join(", ")
            Aircana.human_logger.info "Available hooks: #{available_hooks_list}"
            return
          end

          # Generate the hook if it doesn't exist
          Aircana::Generators::HooksGenerator.create_default_hook(hook_name)

          # Install hooks to Claude settings
          Install.run

          Aircana.human_logger.success "Hook '#{hook_name}' has been enabled."
        end

        def disable(hook_name)
          hook_file = File.join(Aircana.configuration.hooks_dir, "#{hook_name}.sh")

          unless File.exist?(hook_file)
            Aircana.human_logger.warn "Hook '#{hook_name}' is not currently enabled."
            return
          end

          File.delete(hook_file)

          # Reinstall remaining hooks to update Claude settings
          Install.run

          Aircana.human_logger.success "Hook '#{hook_name}' has been disabled."
        end

        def create
          prompt = TTY::Prompt.new

          hook_name = prompt.ask("Hook name (lowercase, no spaces):")
          hook_name = hook_name.strip.downcase.gsub(" ", "_")

          hook_event = prompt.select("Select hook event:", %w[
                                       pre_tool_use
                                       post_tool_use
                                       user_prompt_submit
                                       session_start
                                     ])

          description = prompt.ask("Brief description of what this hook does:")

          create_custom_hook(hook_name, hook_event, description)
        end

        def status
          settings_file = File.join(Aircana.configuration.claude_code_project_config_path, "settings.local.json")

          unless File.exist?(settings_file)
            Aircana.human_logger.info "No Claude settings file found at #{settings_file}"
            return
          end

          begin
            settings = JSON.parse(File.read(settings_file))
            hooks_config = settings["hooks"]

            if hooks_config.nil? || hooks_config.empty?
              Aircana.human_logger.info "No hooks configured in Claude settings."
            else
              Aircana.human_logger.info "Configured hooks in Claude settings:"
              hooks_config.each do |event, configs|
                configs = [configs] unless configs.is_a?(Array)
                configs.each do |config|
                  script_name = File.basename(config["script"], ".sh") if config["script"]
                  Aircana.human_logger.info "  #{event}: #{script_name} (#{config["outputType"]})"
                end
              end
            end
          rescue JSON::ParserError => e
            Aircana.human_logger.error "Invalid JSON in settings file: #{e.message}"
          end
        end

        private

        def installed_hooks
          return [] unless Dir.exist?(Aircana.configuration.hooks_dir)

          Dir.glob("#{Aircana.configuration.hooks_dir}/*.sh").map do |file|
            File.basename(file, ".sh")
          end
        end

        def hook_description(hook_name)
          descriptions = {
            "pre_tool_use" => "General pre-tool validation hook",
            "post_tool_use" => "General post-tool processing hook",
            "user_prompt_submit" => "Add context to user prompts",
            "session_start" => "Initialize session with project context",
            "rubocop_pre_commit" => "Run RuboCop before git commits",
            "rspec_test" => "Run RSpec tests when Ruby files are modified",
            "bundle_install" => "Run bundle install when Gemfile changes"
          }
          descriptions[hook_name] || "Custom hook"
        end

        def create_custom_hook(hook_name, hook_event, description)
          template_content = generate_custom_hook_template(hook_event, description)

          hook_file = File.join(Aircana.configuration.hooks_dir, "#{hook_name}.sh")
          Aircana.create_dir_if_needed(File.dirname(hook_file))

          File.write(hook_file, template_content)
          File.chmod(0o755, hook_file)

          Aircana.human_logger.success "Custom hook created at #{hook_file}"
          Aircana.human_logger.info "You may need to customize the hook script for your specific needs."

          # Optionally offer to open in editor
          prompt = TTY::Prompt.new
          return unless prompt.yes?("Would you like to edit the hook file now?")

          open_file_in_editor(hook_file)
        end

        def generate_custom_hook_template(hook_event, description)
          case hook_event
          when "pre_tool_use"
            generate_pre_tool_use_template(description)
          when "post_tool_use"
            generate_post_tool_use_template(description)
          when "user_prompt_submit"
            generate_user_prompt_submit_template(description)
          when "session_start"
            generate_session_start_template(description)
          else
            generate_basic_template(hook_event, description)
          end
        end

        def generate_pre_tool_use_template(description)
          <<~SCRIPT
            #!/bin/bash
            # Custom pre-tool-use hook: #{description}

            TOOL_NAME="$1"
            TOOL_PARAMS="$2"

            # Add your custom validation logic here
            # Return exit code 0 to allow, exit code 1 to deny

            echo "Pre-tool validation: $TOOL_NAME"

            # Allow by default
            exit 0
          SCRIPT
        end

        def generate_post_tool_use_template(description)
          <<~SCRIPT
            #!/bin/bash
            # Custom post-tool-use hook: #{description}

            TOOL_NAME="$1"
            TOOL_PARAMS="$2"
            TOOL_RESULT="$3"
            EXIT_CODE="$4"

            # Add your custom post-processing logic here

            echo "Post-tool processing: $TOOL_NAME (exit code: $EXIT_CODE)"

            # Always allow result to proceed
            exit 0
          SCRIPT
        end

        def generate_user_prompt_submit_template(description)
          <<~SCRIPT
            #!/bin/bash
            # Custom user prompt submit hook: #{description}

            USER_PROMPT="$1"

            # Add custom context or modify the prompt here
            # Output JSON for advanced control or simple exit code

            echo "Processing user prompt"

            # Simple allow - no modifications
            exit 0
          SCRIPT
        end

        def generate_session_start_template(description)
          <<~SCRIPT
            #!/bin/bash
            # Custom session start hook: #{description}

            # Add session initialization logic here

            echo "Session started in $(pwd)"

            # Simple allow
            exit 0
          SCRIPT
        end

        def generate_basic_template(hook_event, description)
          <<~SCRIPT
            #!/bin/bash
            # Custom #{hook_event} hook: #{description}

            # Add your custom hook logic here

            exit 0
          SCRIPT
        end

        def open_file_in_editor(file_path)
          editor = ENV["EDITOR"] || find_available_editor

          if editor
            Aircana.human_logger.info "Opening #{file_path} in #{editor}..."
            system("#{editor} '#{file_path}'")
          else
            Aircana.human_logger.warn "No editor found. Please edit #{file_path} manually."
          end
        end

        def find_available_editor
          %w[code subl atom nano vim vi].find { |cmd| system("which #{cmd} > /dev/null 2>&1") }
        end
      end
    end
  end
end
