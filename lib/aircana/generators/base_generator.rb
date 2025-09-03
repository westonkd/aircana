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
        prepare_output_directory
        content = generate_content
        write_content(content)
      end

      private

      def prepare_output_directory
        return unless file_out.is_a?(String)

        FileUtils.mkdir_p(File.dirname(file_out))
      end

      def generate_content
        erb = ERB.new(template)
        Aircana.logger.info "Generating #{file_out} from #{file_in}"
        Aircana.logger.debug "With locals: #{locals}"
        erb.result_with_hash(locals)
      end

      def write_content(content)
        if file_out.respond_to?(:write)
          file_out.write(content)
        else
          File.write(file_out, content)
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
