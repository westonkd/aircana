# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
- `bundle exec exe/aircana <command>` - Run commands in development mode
- `bundle install` - Install dependencies
- `bin/setup` - Set up development environment
- `bin/console` - Interactive prompt for experimentation

### Testing and Quality
- `rake spec` or `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/aircana/cli/commands/agents_spec.rb` - Run specific test file
- `bundle exec rspec spec/aircana/cli/commands/agents_spec.rb:15` - Run test at specific line
- `bundle exec rspec --format documentation` - Run tests with detailed output
- `bundle exec rubocop` - Run linter
- `bundle exec rubocop -a` - Run linter with auto-fix
- `rake` - Run both tests and linter (default task)

### Gem Management
- `bundle exec rake build` - Build gem package
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (updates version, creates git tag, pushes to rubygems)

### Aircana CLI Commands
- `aircana add-files` - Interactively add files to current context (uses fzf)
- `aircana add-dir [DIRECTORY_PATH]` - Add all files from directory to context
- `aircana clear-files` - Remove all files from relevant files
- `aircana doctor` - Check system health and dependencies
- `aircana doctor --verbose` - Show detailed dependency information
- `aircana dump-context <agent_name>` - Dump context for specified agent
- `aircana generate` - Generate all configured files
- `aircana install` - Install generated files to Claude Code config
- `aircana agents create` - Create a new agent interactively
- `aircana agents refresh <agent>` - Refresh agent knowledge from Confluence and web sources
- `aircana agents add-url <agent> <url>` - Add a web URL to an agent's knowledge base
- `aircana hooks list` - List all available hooks
- `aircana hooks enable <hook>` - Enable a specific hook
- `aircana hooks disable <hook>` - Disable a specific hook
- `aircana hooks create` - Create custom hook
- `aircana hooks status` - Show hook configuration status

## Architecture

### Core Structure
Aircana is a Ruby gem that provides context management and workflow utilities for AI agents, specifically Claude Code. The main components:

- **CLI Layer** (`lib/aircana/cli/`): Thor-based command line interface with subcommands
  - `app.rb`: Main Thor application defining all commands
  - `subcommand.rb`: Base class for subcommands
  - `shell_command.rb`: Shell command execution utilities
  - `commands/`: Individual command implementations
- **Contexts** (`lib/aircana/contexts/`): Manages different types of context
  - `relevant_files.rb`: Manages current working file set
  - `confluence.rb`: Handles Confluence page fetching and caching
  - `confluence_content.rb`: Processes Confluence content
  - `web.rb`: Handles web URL fetching and HTML to Markdown conversion
  - `local.rb`: Local file context management
- **Generators** (`lib/aircana/generators/`): Template generation system
  - `base_generator.rb`: Base class for all generators
  - `agents_generator.rb`: Generates agent configurations
  - `hooks_generator.rb`: Generates hook configurations
  - `relevant_files_command_generator.rb`: Generates file commands
- **Configuration** (`lib/aircana/configuration.rb`): Centralized configuration management
- **Support Classes**:
  - `human_logger.rb`: User-friendly logging output
  - `system_checker.rb`: Dependency validation
  - `agent.rb`: Agent model and persistence

### Key Concepts
- **Relevant Files**: Current working set of important files stored in `.aircana/relevant_files/`
- **Agents**: Knowledge encapsulation with domain expertise, Confluence sync, and model customization
- **Hooks**: Claude Code integration points for automated workflows
- **Context Management**: Integration with Claude Code through generated templates and configurations

### File Organization
- Configuration files stored in `~/.aircana` (global) and `.aircana/` (project-local)
- Claude Code integration through `~/.claude` and `./.claude` directories
- Generated output goes to `~/.aircana/aircana.out` by default
- Agent knowledge cached in `.aircana/agents/<agent_name>/`
- Hooks stored in `.aircana/hooks/`
- Relevant files tracked in `.aircana/relevant_files/`

### Dependencies
- Thor (~> 0.19.1) for CLI framework
- tty-prompt (~> 0.23.1) for interactive prompts
- Ruby >= 3.3.0 required
- External tools: git, fzf (required), bat, fd (optional)

### Testing
- Uses RSpec for testing with specs in `spec/` directory
- Test files follow naming convention: `spec/<path>/<file>_spec.rb`
- Rubocop configured with custom rules in `.rubocop.yml`
- String style enforced as double quotes

### Knowledge Sources
Agents can sync knowledge from multiple sources:

**Confluence Integration:**
- Set environment variables: `CONFLUENCE_BASE_URL`, `CONFLUENCE_USERNAME`, `CONFLUENCE_API_TOKEN`
- Pages are fetched based on agent name as label
- Content cached locally for offline access

**Web URL Integration:**
- Add URLs directly to agent knowledge bases
- HTML content is automatically converted to Markdown
- Interactive URL collection during agent creation
- Add individual URLs: `aircana agents add-url <agent> <url>`

**Unified Management:**
- Both sources tracked in manifest.json for each agent
- Refresh all sources with `aircana agents refresh <agent>`
- Content stored as Markdown files in `.aircana/agents/<agent>/knowledge/`