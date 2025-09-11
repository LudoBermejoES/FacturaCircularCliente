class CompanyService < ApiService
  class << self
    def all(token:, params: {})
      get('/companies', token: token, params: params)
    end
    
    def find(id, token:)
      get("/companies/#{id}", token: token)
    end
    
    def create(params, token:)
      post('/companies', token: token, body: { company: params })
    end
    
    def update(id, params, token:)
      put("/companies/#{id}", token: token, body: { company: params })
    end
    
    def destroy(id, token:)
      delete("/companies/#{id}", token: token)
    end
    
    # Address management
    def addresses(company_id, token:)
      get("/companies/#{company_id}/addresses", token: token)
    end
    
    def create_address(company_id, params, token:)
      post("/companies/#{company_id}/addresses", token: token, body: { address: params })
    end
    
    def update_address(company_id, address_id, params, token:)
      put("/companies/#{company_id}/addresses/#{address_id}", token: token, body: { address: params })
    end
    
    def destroy_address(company_id, address_id, token:)
      delete("/companies/#{company_id}/addresses/#{address_id}", token: token)
    end
    
    # Search companies
    def search(query, token:)
      get('/companies/search', token: token, params: { q: query })
    end
  end
end