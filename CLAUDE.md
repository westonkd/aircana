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

**Plugin Management:**
- `aircana init [DIRECTORY]` - Initialize a Claude Code plugin in specified directory (defaults to current)
- `aircana init --plugin-name NAME` - Initialize with custom plugin name
- `aircana plugin info` - Display plugin information
- `aircana plugin update` - Update plugin metadata interactively
- `aircana plugin version` - Show current version
- `aircana plugin version bump [major|minor|patch]` - Bump semantic version
- `aircana plugin version set` - Set specific version
- `aircana plugin validate` - Validate plugin structure and manifests

**Agent Management:**
- `aircana agents create` - Create a new agent interactively
- `aircana agents list` - List all configured agents
- `aircana agents refresh <agent>` - Refresh agent knowledge from Confluence and web sources
- `aircana agents refresh-all` - Refresh knowledge for all configured agents
- `aircana agents add-url <agent> <url>` - Add a web URL to an agent's knowledge base

**Hook Management:**
- `aircana hooks list` - List all available hooks
- `aircana hooks enable <hook>` - Enable a specific hook
- `aircana hooks disable <hook>` - Disable a specific hook
- `aircana hooks create` - Create custom hook
- `aircana hooks status` - Show hook configuration status

**System:**
- `aircana doctor` - Check system health and dependencies
- `aircana doctor --verbose` - Show detailed dependency information
- `aircana generate` - Generate plugin components from templates
- `aircana dump-context <agent_name>` - Dump context for specified agent

## Architecture

### Core Structure
Aircana is a Ruby gem that creates and manages Claude Code plugins. The main components:

- **CLI Layer** (`lib/aircana/cli/`): Thor-based command line interface with subcommands
  - `app.rb`: Main Thor application defining all commands
  - `subcommand.rb`: Base class for subcommands
  - `shell_command.rb`: Shell command execution utilities
  - `commands/`: Individual command implementations
    - `init.rb`: Plugin initialization
    - `plugin.rb`: Plugin metadata management
    - `agents.rb`: Agent CRUD operations
    - `hooks.rb`: Hook management
- **Plugin Management**:
  - `plugin_manifest.rb`: Manages `.claude-plugin/plugin.json`
  - `hooks_manifest.rb`: Manages `hooks/hooks.json`
- **Contexts** (`lib/aircana/contexts/`): Manages knowledge sources
  - `confluence.rb`: Handles Confluence page fetching and caching
  - `confluence_content.rb`: Processes Confluence content
  - `web.rb`: Handles web URL fetching and HTML to Markdown conversion
  - `manifest.rb`: Tracks knowledge sources per agent
- **Generators** (`lib/aircana/generators/`): Template generation system
  - `base_generator.rb`: Base class for all generators
  - `agents_generator.rb`: Generates agent configurations
  - Command generators: Generate slash commands from templates
- **Configuration** (`lib/aircana/configuration.rb`): Centralized configuration management with plugin-aware paths
- **Support Classes**:
  - `human_logger.rb`: User-friendly logging output
  - `system_checker.rb`: Dependency validation

### Key Concepts
- **Plugins**: Distributable Claude Code extensions with manifests, agents, commands, and hooks
- **Plugin Manifests**: JSON files defining plugin metadata (`.claude-plugin/plugin.json`)
- **Agents**: Domain-specific experts with dedicated knowledge bases and context windows
- **Knowledge Bases**: Curated documentation from Confluence and web sources
- **Hooks**: Event-driven automation through `hooks/hooks.json`
- **Commands**: Custom slash commands for workflow automation

### File Organization
- **Plugin Structure**:
  - `.claude-plugin/plugin.json` - Plugin manifest with metadata and versioning
  - `agents/` - Agent markdown files and their knowledge directories
  - `commands/` - Slash command markdown files
  - `hooks/` - Hook scripts and hooks.json manifest
- **Configuration**:
  - `~/.aircana` - Global Aircana configuration
  - `~/.aircana/aircana.out` - Generated templates output directory
- **Agent Knowledge**:
  - `agents/<agent_name>/knowledge/` - Cached knowledge base content
  - `agents/<agent_name>/manifest.json` - Tracks knowledge sources

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
- Content stored as Markdown files in `.claude/agents/<agent>/knowledge/`