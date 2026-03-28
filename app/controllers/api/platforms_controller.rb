# frozen_string_literal: true

module Api
  class PlatformsController < BaseController
    def index
      platforms = BlurtConfig::PLATFORMS.map do |name|
        {
          name: name,
          configured: BlurtConfig.platform_configured?(name),
          type: Post::BLOG_PLATFORMS.include?(name) ? "blog" : "social"
        }
      end

      render json: {
        platforms: platforms,
        configured_count: platforms.count { |p| p[:configured] }
      }
    end
  end
end
