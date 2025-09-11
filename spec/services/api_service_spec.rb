require 'rails_helper'

RSpec.describe ApiService do
  let(:token) { 'test_token' }
  let(:endpoint) { '/test' }
  let(:base_url) { 'http://localhost:3001/api/v1' }
  
  describe '.get' do
    context 'when request is successful' do
      let(:response_body) { { 'data' => 'test', 'id' => 1 } }
      
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end
      
      it 'returns parsed JSON response' do
        result = described_class.get(endpoint, token: token)
        expect(result).to eq(response_body.deep_symbolize_keys)
      end
      
      it 'includes authorization header' do
        described_class.get(endpoint, token: token)
        expect(WebMock).to have_requested(:get, "#{base_url}#{endpoint}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
      end
    end
    
    context 'when request returns 401' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
    
    context 'when request returns 404' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end
      
      it 'raises ApiError for not found' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError)
      end
    end
    
    context 'when request returns 422' do
      let(:errors) { { name: ['is required'], email: ['is invalid'] } }
      
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 422, body: { errors: errors }.to_json)
      end
      
      it 'raises ValidationError with errors' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ValidationError) do |error|
          expect(error.errors).to eq(errors.deep_symbolize_keys)
        end
      end
    end
    
    context 'when request returns 500' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 500, body: 'Internal Server Error')
      end
      
      it 'raises ApiError' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError, /Server error/)
      end
    end
    
    context 'with query parameters' do
      let(:params) { { page: 1, per_page: 10, status: 'active' } }
      
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .with(
            query: params,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { data: [] }.to_json)
      end
      
      it 'includes query parameters in request' do
        described_class.get(endpoint, token: token, params: params)
        expect(WebMock).to have_requested(:get, "#{base_url}#{endpoint}")
          .with(query: params)
      end
    end
  end
  
  describe '.post' do
    let(:body) { { name: 'Test', value: 123 } }
    
    context 'when request is successful' do
      let(:response_body) { { 'id' => 1, 'created' => true } }
      
      before do
        stub_request(:post, "#{base_url}#{endpoint}")
          .with(
            body: body.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 201, body: response_body.to_json)
      end
      
      it 'sends POST request with body' do
        result = described_class.post(endpoint, body: body, token: token)
        expect(result).to eq(response_body.deep_symbolize_keys)
      end
      
      it 'includes correct headers' do
        described_class.post(endpoint, body: body, token: token)
        expect(WebMock).to have_requested(:post, "#{base_url}#{endpoint}")
          .with(
            body: body.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            }
          )
      end
    end
  end
  
  describe '.put' do
    let(:body) { { name: 'Updated' } }
    
    before do
      stub_request(:put, "#{base_url}#{endpoint}")
        .with(
          body: body.to_json,
          headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
        )
        .to_return(status: 200, body: { updated: true }.to_json)
    end
    
    it 'sends PUT request with body' do
      result = described_class.put(endpoint, body: body, token: token)
      expect(result).to eq({ updated: true })
    end
  end
  
  describe '.patch' do
    let(:body) { { status: 'active' } }
    
    before do
      stub_request(:patch, "#{base_url}#{endpoint}")
        .with(
          body: body.to_json,
          headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
        )
        .to_return(status: 200, body: { patched: true }.to_json)
    end
    
    it 'sends PATCH request with body' do
      result = described_class.patch(endpoint, body: body, token: token)
      expect(result).to eq({ patched: true })
    end
  end
  
  describe '.delete' do
    before do
      stub_request(:delete, "#{base_url}#{endpoint}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end
    
    it 'sends DELETE request' do
      result = described_class.delete(endpoint, token: token)
      expect(result).to be_nil
    end
  end
  
  describe 'error handling' do
    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_timeout
      end
      
      it 'raises ApiError' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError)
      end
    end
  end
end