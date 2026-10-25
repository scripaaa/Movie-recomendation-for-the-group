require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

module Tmdb
  class MovieSearch
    API_BASE_URL = "https://api.themoviedb.org/3"

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end

    def search(query)
      get_results("/search/movie", { query: query, language: "ru-RU", include_adult: false, page: 1 })
    end

    def popular
      get_results("/movie/popular", { language: "ru-RU", page: 1 })
    end

    def details(tmdb_id)
      movie_id = Integer(tmdb_id, 10)
      get("/movie/#{movie_id}", { language: "ru-RU" })
    rescue ArgumentError, TypeError
      raise NotFoundError, "Invalid TMDB movie ID"
    end

    def discover(genre_ids: [], duration: nil, page: 1)
      filters = { language: "ru-RU", include_adult: false, include_video: false,
                  sort_by: "popularity.desc", page: page, "vote_count.gte" => 50 }
      filters[:with_genres] = genre_ids.join("|") if genre_ids.any?
      if duration
        filters["with_runtime.gte"] = 1
        filters["with_runtime.lte"] = duration
      end
      get_results("/discover/movie", filters)
    end

    private

    def get_results(path, params)
      get(path, params).fetch("results", [])
    end

    def get(path, params)
      token = ENV["TMDB_API_READ_ACCESS_TOKEN"]
      raise ConfigurationError, "TMDB_API_READ_ACCESS_TOKEN is not set" if token.to_s.strip.empty?

      uri = URI("#{API_BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
        http.request(request)
      end

      if response.code == "401"
        raise AuthenticationError, "TMDB rejected the API Read Access Token"
      end
      raise NotFoundError, "TMDB movie was not found" if response.code == "404"

      raise Error, "TMDB responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, Net::HTTPError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, error.class.name
    end
  end
end
