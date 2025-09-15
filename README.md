# Aircana

A Ruby CLI utility for enhanced context management and AI-powered software engineering workflows with Claude Code. Aircana provides intelligent file context management, specialized agent creation, and seamless integration with Claude Code for improved development productivity.

[![Ruby](https://github.com/westonkd/aircana/actions/workflows/main.yml/badge.svg)](https://github.com/westonkd/aircana/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/aircana.svg)](https://badge.fury.io/rb/aircana)

## Installation

Install the gem:

```bash
gem install aircana
```

Or add to your Gemfile:

```ruby
gem 'aircana'
```

Then run:

```bash
bundle install
```

## Features

- **Context Management**: Intelligently manage relevant files for your current work session
- **AI Agents**: Create and manage specialized Claude Code agents with domain-specific knowledge
- **Confluence Integration**: Automatically sync knowledge from Confluence pages to agents
- **Workflow Automation**: Quick-launch specialized planning and work sessions
- **Claude Code Integration**: Seamlessly generate and install configurations for Claude Code

## Usage

### File Context Management

Add files to your current working context:
```bash
aircana add-files          # Interactive file selection
aircana add-dir [PATH]     # Add entire directory
```

Clear your current context:
```bash
aircana clear-files
```

View current context for an agent:
```bash
aircana dump-context [AGENT_NAME]
```

### Agent Management

Create a new specialized agent:
```bash
aircana agents create
```

Refresh agent knowledge from Confluence:
```bash
aircana agents refresh [AGENT_NAME]
```

### Quick Workflows

Launch Claude Code with specialized agents:
```bash
aircana plan    # Start planning session with planner agent
aircana work    # Start work session with worker agent
```

### Configuration Management

Generate all Claude Code configuration files:
```bash
aircana generate
```

Install generated files to Claude Code:
```bash
aircana install
```

## Core Concepts

### Relevant Files
Aircana maintains a curated set of "relevant files" - the current working set of important files for your development session. This context is automatically integrated into Claude Code sessions to provide better assistance.

### Agents
Specialized Claude Code agents with:
- **Domain Knowledge**: Focused expertise in specific areas
- **Confluence Integration**: Automatic knowledge sync from labeled pages
- **Long-term Memory**: Persistent understanding across sessions
- **Customizable Models**: Choose from different Claude models and interface colors

### Knowledge Sources
- **Confluence Pages**: Automatically fetched based on agent labels
- **Local Context**: Project-specific files and configurations
- **Relevant Files**: Current working set managed by Aircana

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run commands in development with `bundle exec exe/aircana <command>`

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/westonkd/aircana.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
