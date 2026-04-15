# frozen_string_literal: true

module BlurtMcp
  module Resources
    module Platforms
      URI = "blurt://platforms"
      MIME_TYPE = "application/json"

      def self.descriptor
        @descriptor ||= MCP::Resource.new(
          uri: URI,
          name: "platforms",
          title: "Configured platforms",
          description: "Platforms Blurt is currently authenticated against",
          mime_type: MIME_TYPE
        )
      end

      def self.read(client)
        data = client.platforms
        platforms = data["platforms"] || []

        payload = {
          count: platforms.length,
          platforms: platforms.map do |p|
            { name: p["name"], type: p["type"] }
          end
        }

        [
          MCP::Resource::TextContents.new(
            uri: URI,
            mime_type: MIME_TYPE,
            text: JSON.pretty_generate(payload)
          )
        ]
      rescue Blurt::Client::Error => e
        [
          MCP::Resource::TextContents.new(
            uri: URI,
            mime_type: MIME_TYPE,
            text: JSON.pretty_generate(error: e.message)
          )
        ]
      end
    end
  end
end
