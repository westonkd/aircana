# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Directory parameter support for `init` command
  - Can now specify target directory: `aircana init /path/to/project`
  - Automatically creates directory if it doesn't exist
  - Defaults to current directory when no path specified

### Changed
- **BREAKING**: Renamed `aircana install` command to `aircana init`
  - More intuitive naming aligned with standard CLI conventions
  - All documentation and help text updated
- **BREAKING**: Agent knowledge bases and manifests moved from `.aircana/agents/` to `.claude/agents/`
  - Agent files and their knowledge are now co-located in the `.claude/agents/` directory
  - This consolidates all Claude Code artifacts in one location
- **BREAKING**: Hook scripts moved from `.aircana/hooks/` to `.claude/hooks/`
  - All Claude Code project artifacts now consolidated in `.claude/` directory
  - Global Aircana configuration remains in `~/.aircana`

### Removed
- Removed `relevant_files` feature from user_prompt_submit hook template
  - Feature was not widely used and added unnecessary complexity

### Migration Guide
To upgrade from a previous version:
1. Update any scripts or documentation that reference `aircana install` to use `aircana init` instead
2. Move existing agent knowledge and hooks manually:
   ```bash
   # Move agent knowledge
   mv .aircana/agents/*/* .claude/agents/
   # Move hooks
   mv .aircana/hooks/* .claude/hooks/
   ```
3. Or refresh all agent knowledge from sources and regenerate hooks:
   ```bash
   aircana agents refresh-all
   aircana init
   ```
4. Remove the old `.aircana` directory if no longer needed (keeping `~/.aircana` for global config)

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
