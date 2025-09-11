require 'rails_helper'

RSpec.describe 'Service Inheritance and Class Behavior' do
  describe 'Service class hierarchy' do
    it 'ensures all services inherit from ApiService' do
      [AuthService, InvoiceService, CompanyService, TaxService, WorkflowService].each do |service_class|
        expect(service_class.superclass).to eq(ApiService)
      end
    end

    it 'ensures services have appropriate class methods' do
      expect(InvoiceService).to respond_to(:all, :find, :create, :update, :delete)
      expect(CompanyService).to respond_to(:all, :find, :create, :update, :delete)
      expect(TaxService).to respond_to(:rates, :calculate, :exemptions)
      expect(WorkflowService).to respond_to(:history, :transition, :definitions)
    end

    it 'ensures AuthService has authentication methods' do
      expect(AuthService).to respond_to(:login)
      expect(AuthService).to respond_to(:logout)
      expect(AuthService).to respond_to(:refresh_token)
      expect(AuthService).to respond_to(:validate_token)
    end
  end

  describe 'Service constant definitions' do
    it 'has proper error class hierarchy' do
      expect(ApiService::ApiError.superclass).to eq(StandardError)
      expect(ApiService::AuthenticationError.superclass).to eq(ApiService::ApiError)
      expect(ApiService::ValidationError.superclass).to eq(ApiService::ApiError)
    end

    it 'has validation error attributes' do
      error = ApiService::ValidationError.new('Test message', { field: 'error' })
      expect(error.message).to eq('Test message')
      expect(error.errors).to eq({ field: 'error' })
    end

    it 'has BASE_URL constant' do
      expect(ApiService::BASE_URL).to be_a(String)
      expect(ApiService::BASE_URL).to match(/albaranes-api:3000\/api\/v1$/)
    end
  end

  describe 'HTTParty integration' do
    it 'includes HTTParty module' do
      expect(ApiService.included_modules).to include(HTTParty)
    end
  end

  describe 'Service instantiation (class methods)' do
    let(:token) { 'test_token' }

    it 'allows instantiation but services use class methods' do
      # Ruby classes can be instantiated by default, services just use class methods
      [ApiService, AuthService, InvoiceService, CompanyService, TaxService, WorkflowService].each do |service_class|
        expect(service_class.new).to be_an_instance_of(service_class)
      end
    end

    it 'validates service method signatures accept keyword arguments' do
      # ApiService base methods use keyword arguments
      expect(ApiService.method(:get).arity).to eq(-2) # endpoint + keyword args
      expect(ApiService.method(:post).arity).to eq(-2)
      expect(ApiService.method(:put).arity).to eq(-2)
      expect(ApiService.method(:patch).arity).to eq(-2)
      expect(ApiService.method(:delete).arity).to eq(-2)
    end
  end
end