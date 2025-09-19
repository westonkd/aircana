# frozen_string_literal: true

require "English"

module Aircana
  module CLI
    module DoctorChecks
      module ClaudeIntegration
        def check_claude_integration
          Aircana.human_logger.info "\nClaude Code Integration:"

          if claude_available?
            log_success("claude", "Claude Code installed")
            check_mcp_tools
          else
            log_failure("claude", "Claude Code not installed")
            log_remedy("Install Claude Code from: https://claude.ai/download")
            @issues_found = true
          end

          check_claude_directories
        end

        def check_mcp_tools
          claude_path = find_claude_path
          return unless claude_path

          check_jira_mcp_tool(claude_path)
        rescue StandardError => e
          log_warning("MCP Jira", "Could not check MCP tool: #{e.message}")
        end

        def check_jira_mcp_tool(claude_path)
          result = `#{claude_path} mcp get jira 2>&1`
          if mcp_tool_installed?(result)
            log_success("MCP Jira", "Atlassian/Jira MCP tool installed")
          else
            log_failure("MCP Jira", "Atlassian/Jira MCP tool not found")
            log_remedy("Install with: claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse")
            @issues_found = true
          end
        end

        def check_claude_directories
          project_claude = File.join(Dir.pwd, ".claude")
          if Dir.exist?(project_claude)
            log_success(".claude", "Project Claude config directory exists")
          else
            log_warning(".claude", "Project Claude config directory not found")
            log_remedy("Will be created when running 'aircana install'")
          end
        end
      end

      module AircanaConfiguration
        def check_aircana_configuration
          Aircana.human_logger.info "\nAircana Configuration:"

          check_directory("~/.aircana", "Global Aircana directory")
          check_directory(".aircana", "Project Aircana directory")
          check_agents_status
          check_relevant_files_status
        end

        def check_agents_status
          agents_dir = File.join(Dir.pwd, ".aircana", "agents")
          if Dir.exist?(agents_dir) && !Dir.empty?(agents_dir)
            agent_count = Dir.glob(File.join(agents_dir, "*.md")).size
            log_success("agents", "#{agent_count} agent(s) configured")
          elsif Dir.exist?(agents_dir)
            log_info("agents", "Agents directory exists but is empty")
          else
            log_info("agents", "No agents configured yet")
            log_remedy("Create agents with: aircana agents create")
          end
        end

        def check_relevant_files_status
          relevant_files_dir = File.join(Dir.pwd, ".aircana", "relevant_files")
          if Dir.exist?(relevant_files_dir) && !Dir.empty?(relevant_files_dir)
            file_count = Dir.glob(File.join(relevant_files_dir, "*")).size
            log_success("relevant_files", "#{file_count} file(s) in context")
          else
            log_info("relevant_files", "No relevant files added yet")
            log_remedy("Add files with: aircana add-files")
          end
        end
      end

      module OptionalIntegrations
        def check_optional_integrations
          Aircana.human_logger.info "\nOptional Integrations:"

          check_confluence_config
          check_editor_config
        end

        def check_confluence_config
          config = Aircana.configuration

          if confluence_configured?(config)
            log_success("Confluence", "API credentials configured")
          else
            log_info("Confluence", "Not configured")
            log_remedy("Set CONFLUENCE_BASE_URL, CONFLUENCE_USERNAME, " \
                       "and CONFLUENCE_API_TOKEN for agent knowledge refresh")
          end
        end

        def check_editor_config
          editor = ENV.fetch("EDITOR", nil)
          available_editors = find_available_editors

          handle_editor_status(editor, available_editors)
        end

        def handle_editor_status(editor, available_editors)
          if editor && command_available?(editor)
            log_success("Editor", "EDITOR set to #{editor}")
          elsif !available_editors.empty?
            log_info("Editor", "Available editors: #{available_editors.join(", ")}")
            log_remedy("Set EDITOR environment variable to prefer one")
          else
            log_warning("Editor", "No common editors found")
            log_remedy("Install an editor or set EDITOR environment variable")
          end
        end
      end
    end
  end
end
