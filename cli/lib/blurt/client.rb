# frozen_string_literal: true

require "faraday"
require "json"
require "erb"

module Blurt
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end
    class ConnectionError < Error; end
    class ServerError < Error; end

    def initialize(config)
      @config = config
    end

    # GET /api/health (no auth)
    def health
      get("/api/health", auth: false)
    end

    # GET /api/posts
    def list_posts(status: nil, platform: nil, after: nil, before: nil)
      params = {}
      params[:status] = status if status
      params[:platform] = platform if platform
      params[:after] = after if after
      params[:before] = before if before
      get("/api/posts", params: params)
    end

    # GET /api/posts/:id
    def get_post(id)
      get("/api/posts/#{encode_id(id)}")
    end

    # POST /api/posts
    def create_post(title: nil, filename: nil, platforms: [], content: "", scheduled_at: nil)
      body = { content: content, platforms: platforms }
      body[:title] = title if title
      body[:filename] = filename if filename
      body[:scheduled_at] = scheduled_at if scheduled_at
      post("/api/posts", body: body)
    end

    # PUT /api/posts/:id
    def update_post(id, **attrs)
      put("/api/posts/#{encode_id(id)}", body: attrs)
    end

    # DELETE /api/posts/:id
    def delete_post(id)
      delete("/api/posts/#{encode_id(id)}")
    end

    # POST /api/posts/:id/publish
    def publish_post(id)
      post("/api/posts/#{encode_id(id)}/publish")
    end

    # GET /api/history
    def history(page: nil, per_page: nil, platform: nil, after: nil, before: nil)
      params = {}
      params[:page] = page if page
      params[:per_page] = per_page if per_page
      params[:platform] = platform if platform
      params[:after] = after if after
      params[:before] = before if before
      get("/api/history", params: params)
    end

    # GET /api/platforms
    def platforms
      get("/api/platforms")
    end

    # GET /api/export (raw ZIP bytes)
    def export
      raw_get("/api/export")
    end

    private

    def connection
      @connection ||= Faraday.new(url: @config.api_url) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter Faraday.default_adapter
        f.options.timeout = 15
        f.options.open_timeout = 5
      end
    end

    def auth_headers
      { "Authorization" => "Bearer #{@config.api_key}" }
    end

    def get(path, params: {}, auth: true)
      headers = auth ? auth_headers : {}
      response = connection.get(path, params, headers)
      handle_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise ConnectionError, "Cannot connect to #{@config.api_url}: #{e.message}"
    end

    def post(path, body: nil)
      response = connection.post(path, body, auth_headers)
      handle_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise ConnectionError, "Cannot connect to #{@config.api_url}: #{e.message}"
    end

    def put(path, body: nil)
      response = connection.put(path, body, auth_headers)
      handle_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise ConnectionError, "Cannot connect to #{@config.api_url}: #{e.message}"
    end

    def delete(path)
      response = connection.delete(path, nil, auth_headers)
      handle_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise ConnectionError, "Cannot connect to #{@config.api_url}: #{e.message}"
    end

    def raw_get(path)
      raw_conn = Faraday.new(url: @config.api_url) do |f|
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
      end
      response = raw_conn.get(path, nil, auth_headers)
      handle_raw_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise ConnectionError, "Cannot connect to #{@config.api_url}: #{e.message}"
    end

    def handle_response(response)
      case response.status
      when 200..299 then response.body
      when 401      then raise AuthenticationError, "Invalid API key"
      when 404      then raise NotFoundError, response.body.is_a?(Hash) ? response.body["error"] : "Not found"
      when 503      then raise ServerError, "Server not configured: #{response.body.is_a?(Hash) ? response.body["error"] : response.body}"
      else
        msg = response.body.is_a?(Hash) ? response.body["error"] : response.body.to_s
        raise Error, "API error (#{response.status}): #{msg}"
      end
    end

    def handle_raw_response(response)
      case response.status
      when 200..299 then response.body
      when 401      then raise AuthenticationError, "Invalid API key"
      else raise Error, "API error (#{response.status})"
      end
    end

    def encode_id(id)
      ERB::Util.url_encode(id)
    end
  end
end
