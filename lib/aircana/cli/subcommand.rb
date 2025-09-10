# frozen_string_literal: true

require "thor"

module Aircana
  module CLI
    class Subcommand < Thor
      def self.banner(command, _namespace = nil, _subcommand = false) # rubocop:disable Style/OptionalBooleanParameter
        "#{basename} #{subcommand_prefix} #{command.usage}"
      end

      def self.subcommand_prefix
        name.gsub(/.*::/, "").gsub(/^[A-Z]/) do |match|
          match[0].downcase
        end.gsub(/[A-Z]/) { |match| "-#{match[0].downcase}" } # rubocop:disable Style/MultilineBlockChain
      end
    end
  end
end
