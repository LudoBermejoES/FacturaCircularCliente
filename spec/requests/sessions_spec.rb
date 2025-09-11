require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /login' do
    it 'renders login form' do
      get login_path
      puts "Response status: #{response.status}"
      if response.status != 200
        puts "Full response body:"
        puts response.body
      end
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign in to FacturaCircular')
    end
  end

  describe 'POST /login' do
    let(:email) { 'admin@example.com' }
    let(:password) { 'password123' }
    let(:auth_response) { build(:auth_response) }

    before do
      # Mock service methods to avoid HTTP calls
      allow(AuthService).to receive(:login).with(any_args).and_return(auth_response)
    end

    it 'authenticates user and redirects to dashboard' do
      post login_path, params: { email: email, password: password }
      expect(response).to redirect_to(dashboard_path)
      expect(session[:access_token]).to eq(auth_response[:access_token])
      expect(session[:refresh_token]).to eq(auth_response[:refresh_token])
    end

    context 'with invalid credentials' do
      before do
        # Mock service to raise authentication error
        allow(AuthService).to receive(:login).and_raise(
          ApiService::AuthenticationError.new('Invalid credentials')
        )
      end

      it 'renders login form with error' do
        post login_path, params: { email: email, password: 'wrong' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid credentials')
      end
    end
  end

  describe 'DELETE /logout' do
    let(:token) { 'test_access_token' }

    before do
      allow_any_instance_of(SessionsController).to receive(:current_user).and_return(double(access_token: token))
      # Mock service methods to avoid HTTP calls
      allow(AuthService).to receive(:logout).with(any_args).and_return({ message: 'Logged out successfully' })
    end

    it 'logs out user and redirects to login' do
      delete logout_path
      expect(response).to redirect_to(login_path)
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
    end
  end
end