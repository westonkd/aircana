# frozen_string_literal: true

module Aircana
  module CLI
    # Custom help formatter to organize commands into logical groups
    module HelpFormatter
      def help(command = nil, subcommand: false)
        if command
          super
        else
          print_grouped_commands
        end
      end

      private

      def print_grouped_commands
        say "Aircana - Context Management for Claude Code", :bold
        command_groups.each { |group_name, commands| print_command_group(group_name, commands) }
        say
        say "Use 'aircana help [COMMAND]' for more information on a specific command.", :green
      end

      def command_groups
        {
          "File Management" => %w[files],
          "Agent Management" => %w[agents],
          "Hook Management" => %w[hooks],
          "Project Management" => %w[project],
          "System" => %w[generate install doctor dump-context]
        }
      end

      def print_command_group(group_name, group_commands)
        print_group_header(group_name)
        group_commands.each { |cmd_name| print_group_command(cmd_name) }
      end

      def print_group_header(group_name)
        say
        say "#{group_name}:", :yellow
      end

      def print_group_command(cmd_name)
        cmd = self.class.commands[cmd_name]
        return unless cmd

        if subcommand?(cmd_name)
          print_subcommand_group(cmd_name, cmd)
        else
          print_command(cmd)
        end
      end

      def subcommand?(cmd_name)
        %w[files agents hooks project].include?(cmd_name)
      end

      def print_subcommand_group(subcommand_name, cmd)
        subcommand_class = get_subcommand_class(subcommand_name)
        return print_command(cmd) unless subcommand_class

        print_subcommands(subcommand_class, subcommand_name)
      end

      def get_subcommand_class(subcommand_name)
        class_name = "#{subcommand_name.capitalize}Subcommand"
        return self.class.const_get(class_name) if self.class.const_defined?(class_name)

        nil
      rescue NameError
        nil
      end

      def print_subcommands(subcommand_class, subcommand_name)
        subcommand_class.commands.each_value do |sub_cmd|
          usage = "aircana #{subcommand_name} #{sub_cmd.usage}"
          desc = sub_cmd.description
          say "  #{usage.ljust(35)} # #{desc}"
        end
      end

      def print_command(cmd)
        usage = "aircana #{cmd.usage}"
        desc = cmd.description
        say "  #{usage.ljust(35)} # #{desc}"
      end
    end
  end
end
