# frozen_string_literal: true

require "English"
module Aircana
  class SystemChecker
    REQUIRED_COMMANDS = {
      "fzf" => {
        purpose: "interactive file selection",
        install: {
          "macOS" => "brew install fzf",
          "Ubuntu/Debian" => "apt install fzf",
          "Fedora/CentOS" => "dnf install fzf",
          "Arch" => "pacman -S fzf",
          "Other" => "https://github.com/junegunn/fzf#installation"
        }
      },
      "git" => {
        purpose: "version control operations",
        install: {
          "macOS" => "brew install git",
          "Ubuntu/Debian" => "apt install git",
          "Fedora/CentOS" => "dnf install git",
          "Arch" => "pacman -S git",
          "Other" => "https://git-scm.com/downloads"
        }
      }
    }.freeze

    OPTIONAL_COMMANDS = {
      "bat" => {
        purpose: "enhanced file previews",
        fallback: "head/cat for basic previews",
        install: {
          "macOS" => "brew install bat",
          "Ubuntu/Debian" => "apt install bat",
          "Fedora/CentOS" => "dnf install bat",
          "Arch" => "pacman -S bat",
          "Other" => "https://github.com/sharkdp/bat#installation"
        }
      },
      "fd" => {
        purpose: "fast file searching",
        fallback: "find command for basic file listing",
        install: {
          "macOS" => "brew install fd",
          "Ubuntu/Debian" => "apt install fd-find",
          "Fedora/CentOS" => "dnf install fd-find",
          "Arch" => "pacman -S fd",
          "Other" => "https://github.com/sharkdp/fd#installation"
        }
      }
    }.freeze

    class << self
      def check_dependencies?(show_optional: false)
        Aircana.human_logger.info "Checking system dependencies..."

        missing_required = check_required_commands
        missing_optional = check_optional_commands if show_optional

        if missing_required.empty? && (missing_optional.nil? || missing_optional.empty?)
          Aircana.human_logger.success "All dependencies satisfied!"
          return true
        end

        show_installation_help(missing_required, missing_optional)
        missing_required.empty? # Return true if no required dependencies missing
      end

      def command_available?(command)
        system("which #{command}", out: File::NULL, err: File::NULL)
      end

      def claude_installed?
        command_available?("claude")
      end

      def mcp_jira_installed?
        return false unless claude_installed?

        result = `claude mcp get jira 2>&1`
        $CHILD_STATUS.success? && !result.include?("not found") && !result.include?("error")
      rescue StandardError
        false
      end

      def check_configuration_directories
        {
          global: File.expand_path("~/.aircana"),
          project: File.join(Dir.pwd, ".aircana"),
          claude_global: File.expand_path("~/.claude"),
          claude_project: File.join(Dir.pwd, ".claude")
        }.transform_values { |path| Dir.exist?(path) }
      end

      def detect_os
        return "macOS" if macos?
        return detect_linux_distribution if linux?

        "Other"
      end

      def macos?
        RbConfig::CONFIG["host_os"].match?(/darwin/)
      end

      def linux?
        RbConfig::CONFIG["host_os"].match?(/linux/)
      end

      def detect_linux_distribution
        return "Ubuntu/Debian" if File.exist?("/etc/debian_version")
        return "Fedora/CentOS" if fedora_or_centos?
        return "Arch" if File.exist?("/etc/arch-release")

        "Other"
      end

      def fedora_or_centos?
        File.exist?("/etc/fedora-release") || File.exist?("/etc/centos-release")
      end

      private

      def check_required_commands
        missing = []

        REQUIRED_COMMANDS.each do |command, info|
          unless command_available?(command)
            Aircana.human_logger.error "Missing required dependency: #{command} (#{info[:purpose]})"
            missing << command
          end
        end

        missing
      end

      def check_optional_commands
        missing = []

        OPTIONAL_COMMANDS.each do |command, info|
          next if command_available?(command)

          Aircana.human_logger.warn "Optional dependency missing: #{command} (#{info[:purpose]})"
          Aircana.human_logger.info "  Fallback: #{info[:fallback]}"
          missing << command
        end

        missing
      end

      def show_installation_help(missing_required, missing_optional)
        return if no_missing_dependencies?(missing_required, missing_optional)

        display_installation_instructions(missing_required, missing_optional)
      end

      def no_missing_dependencies?(missing_required, missing_optional)
        missing_required.empty? && (missing_optional.nil? || missing_optional.empty?)
      end

      def display_installation_instructions(missing_required, missing_optional)
        os = detect_os
        Aircana.human_logger.info "Installation instructions for #{os}:"
        show_commands_installation(missing_required, missing_optional, os)
      end

      def show_commands_installation(missing_required, missing_optional, os)
        [missing_required, missing_optional].compact.flatten.each do |command|
          command_info = REQUIRED_COMMANDS[command] || OPTIONAL_COMMANDS[command]
          install_cmd = command_info[:install][os] || command_info[:install]["Other"]
          Aircana.human_logger.info "  #{command}: #{install_cmd}"
        end
      end
    end
  end
end
