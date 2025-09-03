# frozen_string_literal: true

require "erb"
require "fileutils"
require_relative "helpers"

module Aircana
  module Generators
    class BaseGenerator
      attr_reader :file_in, :file_out

      def initialize(file_in: nil, file_out: nil)
        @file_in = file_in
        @file_out = file_out
      end

      def generate
        FileUtils.mkdir_p(File.dirname(file_out)) if file_out.is_a?(String)

        erb = ERB.new(template)

        Aircana.logger.info "Generating #{file_out} from #{file_in}"
        Aircana.logger.debug "With locals: #{locals}"

        result = erb.result_with_hash(locals)

        # Existing streams like STDOUT
        if file_out.respond_to?(:write)
          file_out.write(result)
        else
          File.write(file_out, result)
        end
      end

      protected

      def locals
        { helpers: Helpers }
      end

      private

      def template
        File.read(file_in)
      end
    end
  end
end
