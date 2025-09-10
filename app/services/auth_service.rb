require 'jwt'

class AuthService < ApiService
  class << self
    def login(email, password)
      response = post('/auth/login', body: {
        email: email,
        password: password
      })
      
      if response && response[:access_token] && response[:refresh_token]
        {
          access_token: response[:access_token],
          refresh_token: response[:refresh_token],
          user: response[:user]
        }
      else
        raise AuthenticationError, 'Invalid login response from server'
      end
    end
    
    def refresh_token(refresh_token)
      response = post('/auth/refresh', body: {
        refresh_token: refresh_token
      })
      
      if response && response[:access_token]
        {
          access_token: response[:access_token],
          refresh_token: response[:refresh_token] || refresh_token
        }
      else
        raise AuthenticationError, 'Failed to refresh token'
      end
    end
    
    def logout(token)
      post('/auth/logout', token: token)
      true
    rescue => e
      Rails.logger.error "Logout failed: #{e.message}"
      true
    end
    
    def validate_token(token)
      return false if token.blank?
      
      begin
        decoded = decode_token(token)
        !token_expired?(decoded)
      rescue JWT::DecodeError => e
        Rails.logger.error "Token validation failed: #{e.message}"
        false
      end
    end
    
    def decode_token(token)
      JWT.decode(
        token, 
        jwt_secret, 
        false,
        { algorithm: 'HS256' }
      ).first
    rescue JWT::DecodeError => e
      Rails.logger.error "Failed to decode token: #{e.message}"
      raise
    end
    
    private
    
    def jwt_secret
      ENV.fetch('JWT_SECRET', 'your-secret-key')
    end
    
    def token_expired?(decoded_token)
      return true unless decoded_token['exp']
      
      Time.at(decoded_token['exp']) < Time.current
    end
  end
end