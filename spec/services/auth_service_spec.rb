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
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .with(body: { grant_type: 'password', email: email, password: password, company_id: nil, remember_me: false }.to_json)
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns tokens and user data' do
        result = described_class.login(email, password)
        expected_result = {
          access_token: 'test_access_token',
          refresh_token: 'test_refresh_token',
          user: { 
            id: 1, 
            email: 'test@example.com', 
            name: 'Test User' 
          },
          company_id: nil,
          companies: []
        }
        expect(result).to eq(expected_result)
      end
      
      it 'sends correct credentials to API' do
        described_class.login(email, password)
        expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .with(
            body: { grant_type: 'password', email: email, password: password, company_id: nil, remember_me: false }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
    
    context 'with invalid credentials' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .with(
            body: { grant_type: 'password', email: email, password: password, company_id: nil, remember_me: false }.to_json,
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
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .with(
            body: { grant_type: 'password', email: email, password: password, company_id: nil, remember_me: true }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(status: 200, body: { access_token: 'token', refresh_token: 'refresh' }.to_json)
      end
      
      it 'includes remember_me in request' do
        described_class.login(email, password, nil, true)
        expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .with(
            body: { grant_type: 'password', email: email, password: password, company_id: nil, remember_me: true }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
  end
  
  describe '.logout' do
    let(:token) { 'test_access_token' }
    
    context 'when logout is successful' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
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
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
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
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
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
        expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
          .with(
            body: { refresh_token: refresh_token }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
      end
    end
    
    context 'when refresh token is expired' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
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
      let(:user_response) do
        { id: 1, email: 'test@example.com', name: 'Test User' }
      end
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/users/profile')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_return(status: 200, body: user_response.to_json)
      end
      
      it 'returns validation result with user data' do
        result = described_class.validate_token(token)
        expect(result[:valid]).to be true
        expect(result[:user]).to eq(user_response)
      end
    end
    
    context 'when token is invalid' do
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/users/profile')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_return(status: 401, body: { error: 'Invalid token' }.to_json)
      end
      
      it 'returns invalid result' do
        result = described_class.validate_token(token)
        expect(result[:valid]).to be false
      end
    end

    context 'when token is blank' do
      it 'returns invalid for nil token' do
        result = described_class.validate_token(nil)
        expect(result[:valid]).to be false
      end

      it 'returns invalid for empty token' do
        result = described_class.validate_token('')
        expect(result[:valid]).to be false
      end

      it 'returns invalid for whitespace token' do
        result = described_class.validate_token('   ')
        expect(result[:valid]).to be false
      end
    end

    context 'when unexpected error occurs' do
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/users/profile')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_raise(StandardError.new('Network failure'))
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs error and returns invalid' do
        result = described_class.validate_token(token)
        expect(result[:valid]).to be false
        expect(Rails.logger).to have_received(:error).with(/Token validation error: Unexpected error: Network failure/)
      end
    end
  end

  describe '.logout' do
    let(:token) { 'test_access_token' }
    
    context 'when logout is successful' do
      let(:response_body) { { message: 'Logged out successfully' } }
      
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' })
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns success message' do
        result = described_class.logout(token)
        expect(result).to eq(response_body)
      end
    end

    context 'when logout API returns nil' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
          .to_return(status: 204, body: '')
      end
      
      it 'returns default message' do
        result = described_class.logout(token)
        expect(result[:message]).to eq('Logged out successfully')
      end
    end

    context 'when AuthenticationError occurs' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
          .to_return(status: 401, body: { error: 'Token invalid' }.to_json)
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs error and re-raises AuthenticationError' do
        expect {
          described_class.logout(token)
        }.to raise_error(ApiService::AuthenticationError)
        expect(Rails.logger).to have_received(:error).with(/Logout failed:/)
      end
    end

    context 'when unexpected error occurs' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
          .with(
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            }
          )
          .to_raise(StandardError.new('Network failure'))
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs error and returns local logout message' do
        result = described_class.logout(token)
        expect(result[:message]).to eq('Logged out locally')
        expect(Rails.logger).to have_received(:error).with(/Logout error: Unexpected error: Network failure/)
      end
    end
  end

  describe '.login edge cases' do
    let(:email) { 'test@example.com' }
    let(:password) { 'password123' }

    context 'when login response is missing tokens' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .to_return(status: 200, body: { user: { id: 1 } }.to_json)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end
      
      it 'raises AuthenticationError for invalid response' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError, /Invalid login response from server/)
        
        expect(Rails.logger).to have_received(:error).with(/AuthService.login failed - response was invalid/)
      end
    end

    context 'when login response is nil' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .to_return(status: 204, body: '')
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end
      
      it 'raises AuthenticationError for nil response' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError, /Invalid login response from server/)
      end
    end

    context 'when access_token is missing' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .to_return(status: 200, body: { refresh_token: 'token', user: { id: 1 } }.to_json)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs specific debug information' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError)
        
        expect(Rails.logger).to have_received(:error).with(/access_token present: false/)
      end
    end

    context 'when refresh_token is missing' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
          .to_return(status: 200, body: { access_token: 'token', user: { id: 1 } }.to_json)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs specific debug information' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError)
        
        expect(Rails.logger).to have_received(:error).with(/refresh_token present: false/)
      end
    end
  end

  describe '.refresh_token edge cases' do
    let(:refresh_token) { 'test_refresh_token' }

    context 'when refresh response is missing access_token' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
          .to_return(status: 200, body: { user: { id: 1 } }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.refresh_token(refresh_token)
        }.to raise_error(ApiService::AuthenticationError, /Failed to refresh token/)
      end
    end

    context 'when refresh response is nil' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
          .to_return(status: 204, body: '')
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.refresh_token(refresh_token)
        }.to raise_error(ApiService::AuthenticationError, /Failed to refresh token/)
      end
    end

    context 'when refresh response omits refresh_token' do
      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/refresh')
          .to_return(status: 200, body: { access_token: 'new_access_token' }.to_json)
      end
      
      it 'uses original refresh_token as fallback' do
        result = described_class.refresh_token(refresh_token)
        expect(result[:access_token]).to eq('new_access_token')
        expect(result[:refresh_token]).to eq(refresh_token)
      end
    end
  end
end
