class UserCompanyService < ApiService
  class << self
    # List all users in a company
    def list_users(company_id:, token:)
      response = get("/companies/#{company_id}/users", token: token)
      
      if response.is_a?(Hash) && response[:data]
        response[:data]
      elsif response.is_a?(Array)
        response
      else
        []
      end
    rescue ApiService::ApiError => e
      Rails.logger.error "Failed to fetch company users: #{e.message}"
      []
    end
    
    # Invite a user to a company
    def invite_user(company_id:, email:, role:, token:)
      post("/companies/#{company_id}/users", token: token, body: {
        email: email,
        role: role
      })
    end
    
    # Update user's role in a company
    def update_user_role(company_id:, user_id:, role:, token:)
      patch("/companies/#{company_id}/users/#{user_id}", token: token, body: {
        role: role
      })
    end
    
    # Remove user from a company
    def remove_user(company_id:, user_id:, token:)
      delete("/companies/#{company_id}/users/#{user_id}", token: token)
    end
    
    # Get available roles for a company
    def available_roles(company_id:, token:)
      response = get("/companies/#{company_id}/roles", token: token)
      response || %w[viewer submitter reviewer accountant manager admin owner]
    rescue ApiService::ApiError
      %w[viewer submitter reviewer accountant manager admin owner]
    end
  end
end