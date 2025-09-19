# frozen_string_literal: true

require "English"
require_relative "doctor_helpers"
require_relative "doctor_checks"

module Aircana
  module CLI
    module Doctor
      class << self
        include DoctorHelpers::Logging
        include DoctorHelpers::SystemChecks
        include DoctorHelpers::ConfigurationChecks
        include DoctorHelpers::InstallCommands
        include DoctorChecks::ClaudeIntegration
        include DoctorChecks::AircanaConfiguration
        include DoctorChecks::OptionalIntegrations

        def run(verbose: false)
          @verbose = verbose
          @issues_found = false

          Aircana.human_logger.info "🔍 Checking Aircana system health...\n"

          check_required_dependencies
          check_claude_integration
          check_optional_dependencies
          check_aircana_configuration
          check_optional_integrations

          display_summary
          @issues_found ? 1 : 0
        end

        private

        def check_required_dependencies
          Aircana.human_logger.info "Required Dependencies:"

          check_command("git", "version control operations", required: true)
          check_command("fzf", "interactive file selection", required: true)
        end

        def check_optional_dependencies
          Aircana.human_logger.info "\nOptional Dependencies:"

          check_optional_tool("bat", "Enhanced file previews available", "will use basic cat for previews")
          check_optional_tool("fd", "Fast file searching available", "will use find command")
        end

        def check_optional_tool(tool, success_message, fallback_message)
          if command_available?(tool)
            log_success(tool, success_message)
          else
            log_info(tool, "Not installed (#{fallback_message})")
            log_remedy("Install with: #{install_command(tool)}") if @verbose
          end
        end

        def display_summary
          Aircana.human_logger.info "\n#{"─" * 50}"

          if @issues_found
            Aircana.human_logger.error "❌ Some issues were found. Please review the remediation steps above."
          else
            Aircana.human_logger.success "✅ All checks passed! Aircana is ready to use."
          end
        end

        def check_command(command, purpose, required: false)
          if command_available?(command)
            log_success(command, "Installed (#{purpose})")
          elsif required
            log_failure(command, "Not installed (required for #{purpose})")
            log_remedy("Install with: #{install_command(command)}")
            @issues_found = true
          else
            log_warning(command, "Not installed (#{purpose})")
            log_remedy("Install with: #{install_command(command)}")
          end
        end
      end
    end
  end
end
