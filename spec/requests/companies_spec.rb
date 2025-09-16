require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  include RequestHelper
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response) }

  # HTTP stubs and authentication mocking handled by RequestHelper
  
  before do
    # Mock CompanyService methods to use the test's company data
    allow(CompanyService).to receive(:all).with(any_args).and_return({ 
      companies: [company], total: 1, meta: { page: 1, pages: 1, total: 1 }
    })
    allow(CompanyService).to receive(:find).with(any_args).and_return(company)
    allow(CompanyService).to receive(:create).with(any_args).and_return(company)
    allow(CompanyService).to receive(:update).with(any_args).and_return(company)
    allow(CompanyService).to receive(:destroy).with(any_args).and_return(true)
    allow(CompanyService).to receive(:addresses).with(any_args).and_return([])
  end

  describe 'GET /companies' do
    it 'lists companies' do
      get companies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Companies')
      expect(response.body).to include(company[:name])
    end
  end

  describe 'GET /companies/new' do
    it 'renders new company form' do
      get new_company_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Company')
      expect(response.body).to include('form')
    end
  end

  describe 'POST /companies' do
    let(:company_params) do
      {
        name: 'Test Company',
        tax_id: 'B12345678',
        email: 'test@example.com'
      }
    end

    it 'creates company and redirects' do
      # Allow the service call and return the mock company
      allow(CompanyService).to receive(:create).and_return(company)
      post companies_path, params: { company: company_params }
      expect(response).to redirect_to(company_path(company[:id]))
      follow_redirect!
      expect(response.body).to include('Company was successfully created')
    end

    it 'handles JSON API format response' do
      # Test with JSON API format response (like the real API returns)
      json_api_response = {
        data: {
          id: "123",
          type: "companies",
          attributes: company.except(:id)
        }
      }
      allow(CompanyService).to receive(:create).and_return(json_api_response)
      
      post companies_path, params: { company: company_params }
      expect(response).to redirect_to(company_path("123"))
      follow_redirect!
      expect(response.body).to include('Company was successfully created')
    end

    context 'with invalid data' do
      it 'renders form with errors' do
        # Override the global mock to raise validation error
        allow(CompanyService).to receive(:create).and_raise(
          ApiService::ValidationError.new("Validation failed", {
            name: ["can't be blank"],
            tax_id: ["can't be blank"]
          })
        )
        
        post companies_path, params: { company: { name: '', tax_id: '', email: '' } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("New Company")
        expect(response.body).to include("form")
      end
    end
  end

  describe 'GET /companies/:id' do
    it 'shows company details' do
      get company_path(company[:id])
      expect(response).to have_http_status(:ok)
      # Company name might contain special characters that get HTML escaped
      expect(response.body).to include(CGI.escapeHTML(company[:name]))
      expect(response.body).to include(company[:tax_id])
    end
  end

  describe 'GET /companies/:id/edit' do
    it 'renders edit form' do
      get edit_company_path(company[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Company')
      # Company name might contain special characters that get HTML escaped
      expect(response.body).to include(CGI.escapeHTML(company[:name]))
    end
  end

  describe 'PUT /companies/:id' do
    let(:updated_params) { { name: 'Updated Company Name' } }

    it 'updates company and redirects' do
      put company_path(company[:id]), params: { company: updated_params }
      expect(response).to redirect_to(company_path(company[:id]))
      follow_redirect!
      expect(response.body).to include('Company was successfully updated')
    end
  end

  describe 'DELETE /companies/:id' do
    it 'deletes company and redirects' do
      delete company_path(company[:id])
      expect(response).to redirect_to(companies_path)
      follow_redirect!
      expect(response.body).to include('Company was successfully deleted')
    end
  end
end