# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.1.0] - 2025-10-16

### Added
- Optional local knowledge base storage for agents
  - New `kb_type` field in agent manifests ("remote" or "local")
  - Local knowledge bases version-controlled in `agents/<name>/knowledge/` directory
  - Auto-synced to `~/.claude/agents/<plugin>-<agent>/knowledge/` via SessionStart hook
  - Remote knowledge bases fetched from Confluence/web to `~/.claude/agents/` (not version controlled)
  - Agent creation wizard prompts for knowledge base type with explanation
  - Refresh commands automatically skip local knowledge base agents
  - Existing agents without `kb_type` field default to "remote" for backward compatibility
- SessionStart hook automatically syncs local knowledge bases to `~/.claude/agents/` on session start
  - Compatible with macOS and Linux
  - Only syncs agents with `kb_type: "local"` in manifest
  - Uses rsync when available, falls back to cp
  - Logs sync operations to `~/.aircana/hooks.log`
- Migration command: `aircana agents migrate-to-local`
  - Migrates remote knowledge bases to local (version-controlled) storage
  - Automatically refreshes knowledge from sources before migration
  - Copies knowledge files from global to local directory
  - Updates manifests and regenerates agent files with correct paths
  - Provides detailed migration summary
- Smart .gitignore management
  - Remote agents: Adds `.claude/agents/*/knowledge/` to .gitignore
  - Local agents: Adds `!agents/*/knowledge/` negation to ensure version control

### Fixed
- Local and remote agents now use consistent runtime path: `~/.claude/agents/<plugin>-<agent>/knowledge/`
- Rubocop linting violations
  - Fixed line length issues with string concatenation
  - Added appropriate Metrics exclusions for complex CLI command methods
  - Removed redundant cop disable directives

## [3.0.0] - 2025-10-12

### Added
- Directory parameter support for `init` command
  - Can now specify target directory: `aircana init /path/to/project`
  - Automatically creates directory if it doesn't exist
  - Defaults to current directory when no path specified
- Plugin manifest system (`.claude-plugin/plugin.json`) for distributable Claude Code plugins
- Plugin management commands: `plugin info`, `plugin update`, `plugin version`, `plugin validate`
- Agent manifest system tracking knowledge sources (Confluence, web URLs)
- Web URL knowledge source support: `agents add-url` command to add public documentation
- Automatic daily knowledge refresh via SessionStart hook
- Development workflow commands: `/plan`, `/record`, `/execute`, `/review`, `/apply-feedback`
- Multiple specialized default agents: planner, executor, reviewer, apply_feedback, jira, sub-agent-coordinator
- Hook management: `hooks list`, `hooks enable`, `hooks disable`, `hooks create`, `hooks status`
- SQS notification integration for Slack/Teams alerts

### Changed
- **BREAKING**: Renamed `aircana install` command to `aircana init`
  - More intuitive naming aligned with standard CLI conventions
  - All documentation and help text updated
- **BREAKING**: Complete architectural shift to Claude Code plugin system
  - Projects now generate distributable plugins instead of local configurations
  - Agent knowledge bases stored globally at `~/.claude/agents/<plugin-name>-<agent-name>/knowledge/`
  - Plugin-local manifests track sources for team collaboration
- **BREAKING**: Agent knowledge bases moved from `.aircana/agents/` to global `~/.claude/agents/`
  - Agent files remain in plugin's `agents/` directory
  - Actual knowledge content stored globally to avoid version control bloat
  - Per-agent manifests track sources for reproducibility
- **BREAKING**: Hook scripts moved from `.aircana/hooks/` to plugin `scripts/` directory
  - Hooks configured via `hooks/hooks.json` manifest
  - All Claude Code artifacts consolidated in plugin structure
  - Global Aircana configuration remains in `~/.aircana`
- Enhanced agent templates with improved knowledge base usage instructions
- Improved CLI help text and command organization

### Removed
- Removed `relevant_files` feature entirely
  - Feature was not widely used and added unnecessary complexity
  - Removed commands: `air-add-relevant-files`
  - Removed stale references in templates and CLI help text
- Removed multi-root project support for simplicity

### Fixed
- Hook installation and generation issues in plugin initialization
- Agent knowledge refresh script generation
- Plugin manifest validation and structure

### Migration Guide
To upgrade from a previous version:
1. Update any scripts or documentation that reference `aircana install` to use `aircana init` instead
2. Projects should be re-initialized as plugins:
   ```bash
   aircana init --plugin-name your-plugin-name
   ```
3. Recreate agents and refresh knowledge:
   ```bash
   aircana agents create
   aircana agents refresh-all
   ```
4. Old `.aircana` local directories are no longer used (except `~/.aircana` for global config)

## [1.5.0] - 2025-09-28

### Added
- New Jira agent: Specialized agent for Jira MCP tool interactions, handles reading and writing tickets efficiently
- New `air-write-plan` command: Generates command for writing structured plans to files
- Write plan command generator for creating plan documentation templates

### Changed
- Enhanced planner agent with improved workflow split into smaller, focused chunks
- Updated planner agent to utilize todo list file management for better task tracking
- Improved planner instructions with clearer guidance for each planning phase
- Updated README with additional documentation

### Fixed
- Fixed test spec that previously required running locally for proper execution

## [1.4.0] - 2025-09-27

### Added
- New planner agent: Strategic project planning agent that integrates with Jira and collaborates with other sub-agents
- New plan command: `aircana generate` now creates an `air-plan.md` command for Claude Code
- Planner agent template with comprehensive workflow for ticket verification, requirements gathering, and sub-agent consultation

### Changed
- Improved knowledge base usage phrasing in agent templates
- Updated agent knowledge base instructions to use more efficient file listing approach
- Added planner to available default agents list

## [0.1.0] - 2025-09-03

### Added
- Initial release
- Context management for AI agents
- File organization utilities
- Template generation
- Claude Code integration
- CLI interface with Thor
- Commands: add_files, clear_files, dump_context, generate, install
