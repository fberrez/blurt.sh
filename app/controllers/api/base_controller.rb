# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_key!

    private

    def authenticate_api_key!
      api_key = ENV["BLURT_API_KEY"]

      if api_key.blank?
        render json: { error: "API not configured: BLURT_API_KEY is not set" }, status: :service_unavailable
        return
      end

      provided = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

      unless ActiveSupport::SecurityUtils.secure_compare(provided.to_s, api_key)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def render_error(message, status: :unprocessable_entity)
      render json: { error: message }, status: status
    end

    def render_not_found(message = "Not found")
      render json: { error: message }, status: :not_found
    end
  end
end
