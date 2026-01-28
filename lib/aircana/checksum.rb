# frozen_string_literal: true

require "digest"

module Aircana
  module Checksum
    def self.compute(content)
      return nil if content.nil? || content.empty?

      "sha256:#{Digest::SHA256.hexdigest(content)}"
    end

    def self.match?(stored_checksum, content)
      return false if stored_checksum.nil? || content.nil?

      compute(content) == stored_checksum
    end
  end
end
