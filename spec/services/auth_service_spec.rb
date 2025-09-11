require 'rails_helper'

RSpec.describe AuthService do
  describe '.login' do
    let(:email) { 'test@example.com' }
    let(:password) { 'password123' }
    
    context 'with valid credentials' do
      let(:response_body) do
        {
          access_token: 'test_access_token',
          refresh_token: 'test_refresh_token',
          user: { 
            id: 1, 
            email: 'test@example.com', 
            name: 'Test User' 
          }
        }
      end
      
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
          .with(body: { email: email, password: password, remember_me: false }.to_json)
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns tokens and user data' do
        result = described_class.login(email, password)
        expect(result).to eq(response_body.deep_symbolize_keys)
      end
      
      it 'sends correct credentials to API' do
        described_class.login(email, password)
        expect(WebMock).to have_requested(:post, 'http://localhost:3001/api/v1/auth/login')
          .with(
            body: { email: email, password: password, remember_me: false }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
    
    context 'with invalid credentials' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
          .with(
            body: { email: email, password: password, remember_me: false }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(status: 401, body: { error: 'Invalid credentials' }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
    
    context 'with remember me enabled' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
          .with(
            body: { email: email, password: password, remember_me: true }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(status: 200, body: { access_token: 'token', refresh_token: 'refresh' }.to_json)
      end
      
      it 'includes remember_me in request' do
        described_class.login(email, password, true)
        expect(WebMock).to have_requested(:post, 'http://localhost:3001/api/v1/auth/login')
          .with(
            body: { email: email, password: password, remember_me: true }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
  end
  
  describe '.logout' do
    let(:token) { 'test_access_token' }
    
    context 'when logout is successful' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/logout')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: { message: 'Logged out successfully' }.to_json)
      end
      
      it 'returns success message' do
        result = described_class.logout(token)
        expect(result).to eq({ message: 'Logged out successfully' })
      end
    end
    
    context 'when token is invalid' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/logout')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' })
          .to_return(status: 401, body: { error: 'Invalid token' }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.logout(token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end
  
  describe '.refresh_token' do
    let(:refresh_token) { 'test_refresh_token' }
    
    context 'when refresh is successful' do
      let(:response_body) do
        {
          access_token: 'new_access_token',
          refresh_token: 'new_refresh_token'
        }
      end
      
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/refresh')
          .with(
            body: { refresh_token: refresh_token }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns new tokens' do
        result = described_class.refresh_token(refresh_token)
        expect(result).to eq({
          access_token: response_body[:access_token],
          refresh_token: response_body[:refresh_token]
        })
      end
      
      it 'sends refresh token in request body' do
        described_class.refresh_token(refresh_token)
        expect(WebMock).to have_requested(:post, 'http://localhost:3001/api/v1/auth/refresh')
          .with(
            body: { refresh_token: refresh_token }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
    
    context 'when refresh token is expired' do
      before do
        stub_request(:post, 'http://localhost:3001/api/v1/auth/refresh')
          .with(
            body: { refresh_token: refresh_token }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(status: 401, body: { error: 'Refresh token expired' }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.refresh_token(refresh_token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end
  
  describe '.validate_token' do
    let(:token) { 'test_access_token' }
    
    context 'when token is valid' do
      let(:response_body) do
        {
          valid: true,
          user: { id: 1, email: 'test@example.com' }
        }
      end
      
      before do
        stub_request(:get, 'http://localhost:3001/api/v1/auth/validate')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns validation result' do
        result = described_class.validate_token(token)
        expect(result).to eq(response_body)
      end
    end
    
    context 'when token is invalid' do
      before do
        stub_request(:get, 'http://localhost:3001/api/v1/auth/validate')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_return(status: 401, body: { error: 'Invalid token' }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.validate_token(token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end
end