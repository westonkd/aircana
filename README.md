# Aircana

An in-progress, humble utility for context management and SE workflows with AI agents (specifically, Claude Code).

This document is a work in progress and will be updated as the project reaches its first release.

[![Ruby](https://github.com/westonkd/aircana/actions/workflows/main.yml/badge.svg)](https://github.com/westonkd/aircana/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/aircana.svg)](https://badge.fury.io/rb/aircana)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aircana'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install aircana

## Usage

### Adding "Relevant Files"

```bash
aircana add-files
```

### Clearing "Relevant Files"

```bash
aircana clear-files
```

### Viewing an agent's current context

```bash
aircana dump-context <agent name>
```

### Generating Templates

```bash
aircana generate
```

### Installing to Claude Code

```bash
aircana install
```

## Concepts

### Knowledge
TODO

#### Third-party
Knowledge of third-party libraries, frameworks, etc

**Strategy**: Existing MCP tools and servers (Context7, AWS MCP tools, etc.)

#### Long-term
Persistent key memories and decisions paritioned by agent and project.

**Strategy**: SessionEnd Hook to capture key details from Claude Code session.

**Domain** - Project-specific understanding

**Relevant Files** - Current working set of important files

### Agents
TODO
**Knowledge Encapsulation**
- Long-term Memory
- Domain Knowledge

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run commands in development with `bundle exec exe/aircana <command>`

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/westonkd/aircana.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
