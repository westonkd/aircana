# frozen_string_literal: true

module Aircana
  module Generators
    module Helpers
      class << self
        def model_instructions(instructions, important: false)
          <<~INSTRUCTIONS
            INSTRUCTIONS #{"IMPORTANT" if important}:
            #{instructions}
          INSTRUCTIONS
        end
      end
    end
  end
end
