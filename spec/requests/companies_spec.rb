require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
  end

  describe 'GET /companies' do
    before do
      stub_request(:get, 'http://localhost:3001/api/v1/companies')
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          query: { 'page' => '1', 'per_page' => '25' }
        )
        .to_return(
          status: 200,
          body: {
            companies: [company, build(:company_response)],
            total: 2,
            page: 1
          }.to_json
        )
    end

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

    before do
      stub_request(:post, 'http://localhost:3001/api/v1/companies')
        .with(
          body: company_params.to_json,
          headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
        )
        .to_return(status: 201, body: company.merge(company_params).to_json)
    end

    it 'creates company and redirects' do
      post companies_path, params: { company: company_params }
      expect(response).to redirect_to(company_path(company[:id]))
      follow_redirect!
      expect(response.body).to include('Company created successfully')
    end

    context 'with invalid data' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/companies')
          .with(
            body: { name: '', tax_id: '', email: '' }.to_json,
            headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
          )
          .to_return(
            status: 422,
            body: {
              errors: {
                name: ["can't be blank"],
                tax_id: ["can't be blank"]
              }
            }.to_json
          )
      end

      it 'renders form with errors' do
        post companies_path, params: { company: { name: '', tax_id: '', email: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can't be blank")
      end
    end
  end

  describe 'GET /companies/:id' do
    before do
      stub_request(:get, "http://localhost:3001/api/v1/companies/#{company[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: company.to_json)
    end

    it 'shows company details' do
      get company_path(company[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(company[:name])
      expect(response.body).to include(company[:tax_id])
    end
  end

  describe 'GET /companies/:id/edit' do
    before do
      stub_request(:get, "http://localhost:3001/api/v1/companies/#{company[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: company.to_json)
    end

    it 'renders edit form' do
      get edit_company_path(company[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Company')
      expect(response.body).to include(company[:name])
    end
  end

  describe 'PUT /companies/:id' do
    let(:updated_params) { { name: 'Updated Company Name' } }

    before do
      stub_request(:put, "http://localhost:3001/api/v1/companies/#{company[:id]}")
        .with(
          body: updated_params.to_json,
          headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
        )
        .to_return(status: 200, body: company.merge(updated_params).to_json)
    end

    it 'updates company and redirects' do
      put company_path(company[:id]), params: { company: updated_params }
      expect(response).to redirect_to(company_path(company[:id]))
      follow_redirect!
      expect(response.body).to include('Company updated successfully')
    end
  end

  describe 'DELETE /companies/:id' do
    before do
      stub_request(:delete, "http://localhost:3001/api/v1/companies/#{company[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end

    it 'deletes company and redirects' do
      delete company_path(company[:id])
      expect(response).to redirect_to(companies_path)
      follow_redirect!
      expect(response.body).to include('Company deleted successfully')
    end
  end
end