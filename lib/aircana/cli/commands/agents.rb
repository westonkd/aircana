# frozen_string_literal: true

require "tty-prompt"
require_relative "../../generators/agents_generator"

module Aircana
  module CLI
    module Agents # rubocop:disable Metrics/ModuleLength
      SUPPORTED_CLAUDE_MODELS = %w[sonnet haiku inherit].freeze
      SUPPORTED_CLAUDE_COLORS = %w[red blue green yellow purple orange pink cyan].freeze

      class << self # rubocop:disable Metrics/ClassLength
        def refresh(agent)
          normalized_agent = normalize_string(agent)
          perform_refresh(normalized_agent)
        rescue Aircana::Error => e
          handle_refresh_error(normalized_agent, e)
        end

        def create # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          prompt = TTY::Prompt.new

          agent_name = prompt.ask("Agent name:")
          short_description = prompt.ask("Briefly describe what your agent does:")
          model = prompt.select("Select a model for your agent:", SUPPORTED_CLAUDE_MODELS)
          color = prompt.select("Select a color for your agent:", SUPPORTED_CLAUDE_COLORS)

          description = description_from_claude(short_description)
          normalized_agent_name = normalize_string(agent_name)

          file = Generators::AgentsGenerator.new(
            agent_name: normalized_agent_name,
            description:,
            short_description:,
            model: normalize_string(model),
            color: normalize_string(color)
          ).generate

          Aircana.human_logger.success "Agent created at #{file}"

          # Prompt for knowledge fetching
          prompt_for_knowledge_fetch(prompt, normalized_agent_name)

          # Prompt for agent file review
          prompt_for_agent_review(prompt, file)

          Aircana.human_logger.success "Agent '#{agent_name}' setup complete!"
        end

        private

        def perform_refresh(normalized_agent)
          confluence = Aircana::Contexts::Confluence.new
          pages_count = confluence.fetch_pages_for(agent: normalized_agent)

          log_refresh_result(normalized_agent, pages_count)
        end

        def log_refresh_result(normalized_agent, pages_count)
          if pages_count.positive?
            Aircana.human_logger.success "Successfully refreshed #{pages_count} pages for agent '#{normalized_agent}'"
          else
            log_no_pages_found(normalized_agent)
          end
        end

        def log_no_pages_found(normalized_agent)
          Aircana.human_logger.info "No pages found for agent '#{normalized_agent}'. " \
                                    "Make sure pages are labeled with '#{normalized_agent}' in Confluence."
        end

        def handle_refresh_error(normalized_agent, error)
          Aircana.human_logger.error "Failed to refresh agent '#{normalized_agent}': #{error.message}"
          exit 1
        end

        def normalize_string(string)
          string.strip.downcase.gsub(" ", "-")
        end

        def description_from_claude(description)
          prompt = build_agent_description_prompt(description)
          claude_client = Aircana::LLM::ClaudeClient.new
          claude_client.prompt(prompt)
        end

        def build_agent_description_prompt(description)
          <<~PROMPT
            Create a concise Claude Code agent description file (without frontmatter)
            for an agent that is described as: #{description}.

            The agent should be specialized and focused on its domain knowledge.
            Include instructions that the agent should primarily rely on information
            from its knowledge base rather than general knowledge when answering questions
            within its domain.

            Print the output to STDOUT only, without any additional commentary.
          PROMPT
        end

        def prompt_for_knowledge_fetch(prompt, normalized_agent_name) # rubocop:disable Metrics/MethodLength
          return unless confluence_configured?

          if prompt.yes?("Would you like to fetch knowledge for this agent from Confluence now?")
            Aircana.human_logger.info "Fetching knowledge from Confluence..."
            perform_refresh(normalized_agent_name)
          else
            Aircana.human_logger.info(
              "Skipping knowledge fetch. You can run 'aircana agents refresh #{normalized_agent_name}' later."
            )
          end
        rescue Aircana::Error => e
          Aircana.human_logger.warn "Failed to fetch knowledge: #{e.message}"
          Aircana.human_logger.info "You can try again later with 'aircana agents refresh #{normalized_agent_name}'"
        end

        def prompt_for_agent_review(prompt, file_path)
          Aircana.human_logger.info "Agent file created at: #{file_path}"

          return unless prompt.yes?("Would you like to review and edit the agent file?")

          open_file_in_editor(file_path)
        end

        def confluence_configured? # rubocop:disable Metrics/AbcSize
          config = Aircana.configuration

          base_url_present = !config.confluence_base_url.nil? && !config.confluence_base_url.empty?
          username_present = !config.confluence_username.nil? && !config.confluence_username.empty?
          token_present = !config.confluence_api_token.nil? && !config.confluence_api_token.empty?

          base_url_present && username_present && token_present
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
