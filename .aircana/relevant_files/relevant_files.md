# Relevant Files
INSTRUCTIONS:
The following files are considered important for the current task.

Use them for:
  - Understanding task context
  - Examples of how to structure your solutions



## File: /home/wdransfield/GitHub/aircana/CLAUDE.md
```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
- `bundle exec exe/aircana <command>` - Run commands in development mode
- `bundle install` - Install dependencies
- `bin/setup` - Set up development environment
- `bin/console` - Interactive prompt for experimentation

### Testing and Quality
- `rake spec` or `bundle exec rspec` - Run tests
- `bundle exec rubocop` - Run linter
- `rake` - Run both tests and linter (default task)

### Gem Management
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (updates version, creates git tag, pushes to rubygems)

### Aircana CLI Commands
- `aircana add-files` - Interactively add files to current context
- `aircana add-dir [DIRECTORY_PATH]` - Add all files from directory to context
- `aircana clear-files` - Remove all files from relevant files
- `aircana dump-context <agent_name>` - Dump context for specified agent
- `aircana generate` - Generate all configured files
- `aircana install` - Install generated files to Claude Code config
- `aircana agents create` - Create a new agent
- `aircana agents refresh <agent>` - Refresh agent knowledge from Confluence pages with matching labels

## Architecture

### Core Structure
Aircana is a Ruby gem that provides context management and workflow utilities for AI agents, specifically Claude Code. The main components:

- **CLI Layer** (`lib/aircana/cli/`): Thor-based command line interface with subcommands
- **Contexts** (`lib/aircana/contexts/`): Manages different types of context (relevant files, local, confluence)
- **Generators** (`lib/aircana/generators/`): Template generation system for Claude Code integration
- **Configuration** (`lib/aircana/configuration.rb`): Centralized configuration management

### Key Concepts
- **Relevant Files**: Current working set of important files stored in `.aircana/relevant_files/`
- **Agents**: Knowledge encapsulation with long-term memory and domain knowledge
- **Context Management**: Integration with Claude Code through generated templates and configurations

### File Organization
- Configuration files stored in `~/.aircana` (global) and `.aircana/` (project-local)
- Claude Code integration through `~/.claude` and `./.claude` directories
- Generated output goes to `~/.aircana/aircana.out` by default

### Dependencies
- Thor (~> 0.19.1) for CLI framework  
- tty-prompt (~> 0.23.1) for interactive prompts
- Ruby >= 3.3.0 required

### Testing
Uses RSpec for testing with specs in `spec/` directory. Run individual tests with standard RSpec patterns.
```

## File: /home/wdransfield/GitHub/aircana/Rakefile
```
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

```

