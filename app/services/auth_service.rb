class AuthService < ApiService
  class << self
    def login(email, password, company_id = nil, remember_me = false)
      Rails.logger.info "DEBUG: AuthService.login called with email=#{email}, company_id=#{company_id}"
      response = post('/auth/login', body: {
        grant_type: 'password',
        email: email,
        password: password,
        company_id: company_id,
        remember_me: remember_me
      })
      Rails.logger.info "DEBUG: AuthService.login got response: #{response.inspect}"
      
      if response && response[:access_token] && response[:refresh_token]
        # Extract user/client information from the response
        client_info = response[:client] || response[:user]
        
        result = {
          access_token: response[:access_token],
          refresh_token: response[:refresh_token],
          user: client_info,
          company_id: client_info&.[](:company_id),
          companies: client_info&.[](:companies) || []
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
      
      # Use profile endpoint to validate token since /auth/validate doesn't exist
      response = get('/users/profile', token: token)
      { valid: true, user: response }
    rescue ApiService::AuthenticationError => e
      Rails.logger.error "Token validation failed: #{e.message}"
      { valid: false }
    rescue => e
      Rails.logger.error "Token validation error: #{e.message}"
      { valid: false }
    end
    
    def switch_company(token, company_id)
      Rails.logger.info "DEBUG: AuthService.switch_company called with company_id=#{company_id}"
      response = post('/auth/switch_company', token: token, body: {
        company_id: company_id
      })
      
      if response && response[:access_token]
        client_info = response[:client] || response[:user]
        {
          access_token: response[:access_token],
          refresh_token: response[:refresh_token] || token,
          user: client_info,
          company_id: client_info&.[](:company_id),
          companies: client_info&.[](:companies) || []
        }
      else
        raise ApiService::AuthenticationError, 'Failed to switch company'
      end
    end
    
    def user_companies(token)
      Rails.logger.info "DEBUG: AuthService.user_companies called"
      response = get('/auth/companies', token: token)
      response || []
    rescue => e
      Rails.logger.error "Failed to fetch user companies: #{e.message}"
      []
    end
  end
end
