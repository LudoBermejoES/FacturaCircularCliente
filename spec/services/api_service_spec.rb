require 'rails_helper'

RSpec.describe ApiService do
  let(:token) { 'test_token' }
  let(:endpoint) { '/test' }
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }
  
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
        }.to raise_error(ApiService::ApiError)
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
    context 'when network timeout occurs' do
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

    context 'when HTTParty error occurs' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_raise(HTTParty::Error.new('Connection failed'))
      end
      
      it 'raises ApiError with network error message' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError, /Network error: Connection failed/)
      end
    end

    context 'when unexpected error occurs' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_raise(StandardError.new('Unexpected'))
      end
      
      it 'raises ApiError with unexpected error message' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError, /Unexpected error: Unexpected/)
      end
    end

    context 'when re-raising existing ApiService errors' do
      before do
        allow(HTTParty).to receive(:get).and_raise(ApiService::AuthenticationError.new('Auth failed'))
      end
      
      it 'does not wrap AuthenticationError' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::AuthenticationError, 'Auth failed')
      end
    end

    context 'when re-raising ValidationError' do
      before do
        allow(HTTParty).to receive(:post).and_raise(ApiService::ValidationError.new('Validation failed', { name: ['required'] }))
      end
      
      it 'does not wrap ValidationError' do
        expect {
          described_class.post(endpoint, token: token, body: {})
        }.to raise_error(ApiService::ValidationError, 'Validation failed')
      end
    end
  end

  describe 'response parsing' do
    context 'when response body is blank' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 204, body: '')
      end
      
      it 'returns nil for blank response' do
        result = described_class.get(endpoint, token: token)
        expect(result).to be_nil
      end
    end

    context 'when response is not valid JSON' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 200, body: 'invalid json{')
        allow(Rails.logger).to receive(:error)
      end
      
      it 'returns raw body when JSON parse fails' do
        result = described_class.get(endpoint, token: token)
        expect(result).to eq('invalid json{')
        expect(Rails.logger).to have_received(:error).with(/Failed to parse response JSON/)
      end
    end

    context 'when 422 validation error has different error format' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 422, body: { error: 'Single error message' }.to_json)
      end
      
      it 'handles single error message format' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ValidationError) do |error|
          expect(error.errors).to eq('Single error message')
        end
      end
    end

    context 'when 422 validation error parsing fails' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 422, body: 'invalid json')
      end
      
      it 'handles parsing errors gracefully' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ValidationError) do |error|
          expect(error.errors).to eq({})
        end
      end
    end

    context 'when validation error response is not a hash' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 422, body: '"not a hash"')
      end
      
      it 'returns empty hash for non-hash body' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ValidationError) do |error|
          expect(error.errors).to eq({})
        end
      end
    end
  end

  describe 'HTTP status code handling' do
    context 'when 403 Forbidden' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 403, body: { error: 'Forbidden' }.to_json)
      end
      
      it 'raises ApiError with permission message' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError, /You do not have permission/)
      end
    end

    context 'when unexpected status code' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 418, body: 'I am a teapot')
      end
      
      it 'raises ApiError with unexpected response message' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ApiError, /Unexpected response: 418/)
      end
    end

    context 'when server error (500-599)' do
      [500, 502, 503, 504].each do |status_code|
        context "when status code is #{status_code}" do
          before do
            stub_request(:get, "#{base_url}#{endpoint}")
              .to_return(status: status_code, body: 'Server Error')
          end
          
          it 'raises ApiError with server error message' do
            expect {
              described_class.get(endpoint, token: token)
            }.to raise_error(ApiService::ApiError, /Server error. Please try again later./)
          end
        end
      end
    end
  end

  describe 'request building' do
    context 'without token' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .with(headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
          .to_return(status: 200, body: '{}')
      end

      it 'makes request without Authorization header' do
        described_class.get(endpoint)
        expect(WebMock).to have_requested(:get, "#{base_url}#{endpoint}")
          .with(headers: { 'Content-Type' => 'application/json' })
      end
    end

    context 'without body for POST request' do
      before do
        stub_request(:post, "#{base_url}#{endpoint}")
          .with(headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' })
          .to_return(status: 201, body: '{}')
      end

      it 'makes POST request without body JSON' do
        described_class.post(endpoint, token: token)
        expect(WebMock).to have_requested(:post, "#{base_url}#{endpoint}")
          .with(headers: { 'Content-Type' => 'application/json' })
      end
    end

    context 'with nil query params' do
      before do
        stub_request(:get, "#{base_url}#{endpoint}")
          .to_return(status: 200, body: '{}')
      end

      it 'handles nil query params gracefully' do
        described_class.get(endpoint, token: token, params: nil)
        expect(WebMock).to have_requested(:get, "#{base_url}#{endpoint}")
      end
    end
  end
end