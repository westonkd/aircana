# frozen_string_literal: true

module Aircana
  module CLI
    module DoctorHelpers
      module Logging
        def log_success(label, message)
          Aircana.human_logger.success "  ✅ #{label.ljust(15)} #{message}"
        end

        def log_failure(label, message)
          Aircana.human_logger.error "  ❌ #{label.ljust(15)} #{message}"
        end

        def log_warning(label, message)
          Aircana.human_logger.warn "  ⚠️  #{label.ljust(15)} #{message}"
        end

        def log_info(label, message)
          Aircana.human_logger.info "  ℹ️  #{label.ljust(15)} #{message}"
        end

        def log_remedy(message)
          Aircana.human_logger.info "     → #{message}"
        end
      end

      module SystemChecks
        def command_available?(command)
          system("which #{command}", out: File::NULL, err: File::NULL)
        end

        def claude_available?
          claude_path = find_claude_path
          !claude_path.nil? && File.executable?(claude_path)
        end

        def find_claude_path
          possible_paths = [
            File.expand_path("~/.claude/local/claude"),
            `which claude 2>/dev/null`.strip,
            "/usr/local/bin/claude"
          ]

          possible_paths.each do |path|
            return path if !path.empty? && File.exist?(path) && File.executable?(path)
          end

          return "claude" if system("which claude > /dev/null 2>&1")

          nil
        end

        def detect_os
          return "macOS" if RUBY_PLATFORM.match?(/darwin/)
          return "Ubuntu/Debian" if File.exist?("/etc/debian_version")

          "Other"
        end
      end

      module ConfigurationChecks
        def confluence_configured?(config)
          !config.confluence_base_url.to_s.empty? &&
            !config.confluence_username.to_s.empty? &&
            !config.confluence_api_token.to_s.empty?
        end

        def find_available_editors
          %w[code subl atom nano nvim vim vi].select { |cmd| command_available?(cmd) }
        end

        def check_directory(path, description)
          expanded_path = File.expand_path(path)
          if Dir.exist?(expanded_path)
            log_success(File.basename(path), "#{description} exists")
          else
            log_info(File.basename(path), "#{description} not found")
            log_remedy("Will be created on first use")
          end
        end
      end

      module InstallCommands
        INSTALL_COMMANDS = {
          "git" => {
            "macOS" => "brew install git",
            "Ubuntu/Debian" => "apt install git",
            "Other" => "https://git-scm.com/downloads"
          },
          "fzf" => {
            "macOS" => "brew install fzf",
            "Ubuntu/Debian" => "apt install fzf",
            "Other" => "https://github.com/junegunn/fzf#installation"
          },
          "bat" => {
            "macOS" => "brew install bat",
            "Ubuntu/Debian" => "apt install bat",
            "Other" => "https://github.com/sharkdp/bat#installation"
          },
          "fd" => {
            "macOS" => "brew install fd",
            "Ubuntu/Debian" => "apt install fd-find",
            "Other" => "https://github.com/sharkdp/fd#installation"
          }
        }.freeze

        def install_command(tool)
          os = detect_os
          INSTALL_COMMANDS.dig(tool, os) || INSTALL_COMMANDS.dig(tool, "Other") || "Check package manager"
        end
      end
    end
  end
end
