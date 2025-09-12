# frozen_string_literal: true

module Aircana
  module Contexts
    module ConfluenceSetup
      def setup_httparty
        config = Aircana.configuration

        self.class.base_uri config.confluence_base_url
        self.class.basic_auth config.confluence_username, config.confluence_api_token
        self.class.headers "Content-Type" => "application/json"
      end
    end
  end
end
