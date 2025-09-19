require 'httparty'

class ApiService
  include HTTParty
  
  BASE_URL = ENV.fetch('API_BASE_URL', 'http://albaranes-api:3000/api/v1')
  
  class ApiError < StandardError; end
  class AuthenticationError < ApiError; end
  class ValidationError < ApiError
    attr_reader :errors
    
    def initialize(message, errors = {})
      super(message)
      @errors = errors
    end
  end
  
  class << self
    def get(endpoint, token: nil, params: {})
      authenticated_request(:get, endpoint, token: token, query: params)
    end
    
    def post(endpoint, token: nil, body: {})
      authenticated_request(:post, endpoint, token: token, body: body)
    end
    
    def put(endpoint, token: nil, body: {})
      authenticated_request(:put, endpoint, token: token, body: body)
    end
    
    def patch(endpoint, token: nil, body: {})
      authenticated_request(:patch, endpoint, token: token, body: body)
    end
    
    def delete(endpoint, token: nil)
      authenticated_request(:delete, endpoint, token: token)
    end
    
    private
    
    def authenticated_request(method, endpoint, token: nil, body: nil, query: nil)
      options = build_request_options(token: token, body: body, query: query)
      url = "#{BASE_URL}#{endpoint}"

      Rails.logger.info "API Request: #{method.upcase} #{url}"
      Rails.logger.info "API Request Body: #{body.inspect}" if body
      Rails.logger.info "API Request Headers: #{options[:headers].inspect}"

      response = HTTParty.send(method, url, options)

      Rails.logger.info "API Response Code: #{response.code}"
      Rails.logger.info "API Response Body (first 500 chars): #{response.body.to_s[0..500]}" if response.body

      handle_response(response)
    rescue HTTParty::Error => e
      Rails.logger.error "API Request Failed: #{e.message}"
      raise ApiError, "Network error: #{e.message}"
    rescue AuthenticationError, ValidationError => e
      # Re-raise our own exceptions without wrapping
      raise e
    rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
      raise ApiError, "Unexpected error: #{e.message}"
    end
    
    def build_request_options(token: nil, body: nil, query: nil)
      options = {
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      }
      
      options[:headers]['Authorization'] = "Bearer #{token}" if token
      options[:body] = body.to_json if body
      options[:query] = query if query
      
      options
    end
    
    def handle_response(response)
      case response.code
      when 200..299
        parse_response_body(response)
      when 401
        raise AuthenticationError, 'Authentication failed. Please login again.'
      when 403
        raise ApiError, 'You do not have permission to perform this action.'
      when 404
        raise ApiError, 'The requested resource was not found.'
      when 422
        Rails.logger.info "DEBUG: ApiService - 422 response body: #{response.body}"
        errors = parse_validation_errors(response)
        Rails.logger.info "DEBUG: ApiService - parsed errors: #{errors.inspect}"
        raise ValidationError.new('Validation failed', errors)
      when 500..599
        raise ApiError, 'Server error. Please try again later.'
      else
        raise ApiError, "Unexpected response: #{response.code} - #{response.message}"
      end
    end
    
    def parse_response_body(response)
      return nil if response.body.blank?

      parsed = JSON.parse(response.body)
      parsed.is_a?(Hash) ? parsed.deep_symbolize_keys : parsed
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse response JSON: #{e.message}"
      response.body
    end
    
    def parse_validation_errors(response)
      body = parse_response_body(response)
      return {} unless body.is_a?(Hash)

      # Now that parse_response_body returns symbolized keys, we can use symbol access
      body[:errors] || body[:error] || {}
    rescue
      {}
    end
  end
end