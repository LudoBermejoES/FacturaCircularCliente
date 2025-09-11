class AuthService < ApiService
  class << self
    def login(email, password, remember_me = false)
      Rails.logger.info "DEBUG: AuthService.login called with email=#{email}"
      response = post('/auth/login', body: {
        email: email,
        password: password,
        remember_me: remember_me
      })
      Rails.logger.info "DEBUG: AuthService.login got response: #{response.inspect}"
      
      if response && response[:access_token] && response[:refresh_token]
        result = {
          access_token: response[:access_token],
          refresh_token: response[:refresh_token],
          user: response[:user]
        }
        Rails.logger.info "DEBUG: AuthService.login returning: #{result.inspect}"
        result
      else
        Rails.logger.error "DEBUG: AuthService.login failed - response was invalid"
        Rails.logger.error "DEBUG: response present: #{response.present?}"
        Rails.logger.error "DEBUG: access_token present: #{response&.[](:access_token).present?}"
        Rails.logger.error "DEBUG: refresh_token present: #{response&.[](:refresh_token).present?}"
        raise ApiService::AuthenticationError, 'Invalid login response from server'
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
        raise ApiService::AuthenticationError, 'Failed to refresh token'
      end
    end
    
    def logout(token)
      response = post('/auth/logout', token: token)
      response || { message: 'Logged out successfully' }
    rescue ApiService::AuthenticationError => e
      # Even if logout fails on server, clear local session
      Rails.logger.error "Logout failed: #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "Logout error: #{e.message}"
      { message: 'Logged out locally' }
    end
    
    def validate_token(token)
      return { valid: false } if token.blank?
      
      response = get('/auth/validate', token: token)
      response || { valid: false }
    rescue ApiService::AuthenticationError => e
      Rails.logger.error "Token validation failed: #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "Token validation error: #{e.message}"
      { valid: false }
    end
  end
end