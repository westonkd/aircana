# frozen_string_literal: true

module Aircana
  class FzfHelper
    class << self
      def select_files_interactively(header: "Select files", multi: true)
        return [] unless fzf_available?

        execute_fzf_selection(header: header, multi: multi)
      rescue StandardError => e
        Aircana.human_logger.error "File selection failed: #{e.message}"
        []
      end

      def fzf_available?
        return true if command_available?("fzf")

        handle_missing_dependency
        false
      end

      def execute_fzf_selection(header:, multi:)
        command = build_fzf_command(header: header, multi: multi)
        result = `#{command}`.strip
        return [] if result.empty?

        result.split("\n").map(&:strip).reject(&:empty?)
      end

      private

      def command_available?(command)
        system("which #{command}", out: File::NULL, err: File::NULL)
      end

      def handle_missing_dependency
        Aircana.human_logger.error "fzf is required but not installed"
        Aircana.human_logger.info "To install fzf:"
        Aircana.human_logger.info "  • macOS: brew install fzf"
        Aircana.human_logger.info "  • Ubuntu/Debian: apt install fzf"
        Aircana.human_logger.info "  • Other: https://github.com/junegunn/fzf#installation"
      end

      def build_fzf_command(header:, multi:)
        options = base_fzf_options(header: header, multi: multi)
        preview_options = preview_command_options
        key_bindings = key_binding_options

        "#{generate_file_list_command} | fzf #{options} #{preview_options} #{key_bindings}"
      end

      def base_fzf_options(header:, multi:)
        options = build_fzf_option_list(multi: multi)
        options += build_fzf_display_options(header: header)
        options.join(" ")
      end

      def build_fzf_option_list(multi:)
        options = ["--ansi", "--border", "--height=80%", "--layout=reverse", "--info=inline"]
        options << "--multi" if multi
        options
      end

      def build_fzf_display_options(header:)
        [
          "--header='#{header}'",
          "--header-lines=0",
          "--prompt='❯ '",
          "--pointer='▶'",
          "--marker='✓'"
        ]
      end

      def preview_command_options
        preview_cmd = preview_command
        return "" if preview_cmd.nil?

        [
          "--preview='#{preview_cmd}'",
          "--preview-window='right:60%:wrap'",
          "--preview-label='Preview'"
        ].join(" ")
      end

      def preview_command
        # Try to use bat for syntax highlighting, fall back to head/cat
        if command_available?("bat")
          "bat --color=always --style=header,grid --line-range :50 {}"
        elsif command_available?("head")
          "head -50 {}"
        else
          "cat {}"
        end
      end

      def key_binding_options
        [
          "--bind='ctrl-a:select-all'",
          "--bind='ctrl-d:deselect-all'",
          "--bind='ctrl-/:toggle-preview'",
          "--bind='ctrl-u:preview-page-up'",
          "--bind='ctrl-n:preview-page-down'",
          "--bind='?:toggle-preview'"
        ].join(" ")
      end

      def generate_file_list_command
        # Use fd if available for better performance and .gitignore respect
        if command_available?("fd")
          "fd --type f --hidden --exclude .git"
        else
          "find . -type f -not -path '*/\\.git/*' -not -path '*/node_modules/*' -not -path '*/\\.vscode/*'"
        end
      end
    end
  end
end
