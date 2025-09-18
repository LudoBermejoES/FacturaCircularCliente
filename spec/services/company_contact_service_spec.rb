require 'rails_helper'

RSpec.describe CompanyContactService, type: :service do
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }
  let(:token) { 'test_token' }
  let(:company_id) { '1859' }
  let(:contact_id) { '112' }

  describe '.all' do
    let(:response_data) {
      {
        data: [
          {
            id: "112",
            type: "company_contacts",
            attributes: {
              legal_name: "DataCenter Barcelona S.A.",
              tax_id: "A22222222",
              email: "services@datacenterbarcelona.com",
              phone: "+34 933 789 012",
              is_active: true,
              created_at: "2025-09-18T10:45:11.882+02:00",
              updated_at: "2025-09-18T10:45:11.882+02:00"
            }
          }
        ],
        meta: {
          total: 1,
          page_count: 1,
          current_page: 1,
          per_page: 25
        }
      }
    }

    before do
      stub_request(:get, "#{base_url}/companies/#{company_id}/contacts")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns transformed contacts data' do
      result = CompanyContactService.all(company_id: company_id, token: token)

      expect(result[:contacts]).to be_an(Array)
      expect(result[:contacts].first[:id]).to eq("112")
      expect(result[:contacts].first[:company_name]).to eq("DataCenter Barcelona S.A.")
      expect(result[:contacts].first[:legal_name]).to eq("DataCenter Barcelona S.A.")
      expect(result[:contacts].first[:tax_id]).to eq("A22222222")
      expect(result[:contacts].first[:email]).to eq("services@datacenterbarcelona.com")
      expect(result[:contacts].first[:phone]).to eq("+34 933 789 012")
      expect(result[:meta][:total]).to eq(1)
    end

    it 'applies filters when provided' do
      filters = { search: 'DataCenter' }

      stub_request(:get, "#{base_url}/companies/#{company_id}/contacts")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          query: { search: 'DataCenter' }
        )
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })

      result = CompanyContactService.all(company_id: company_id, token: token, filters: filters)

      expect(result[:contacts]).to be_an(Array)
      expect(result[:contacts].first[:company_name]).to eq("DataCenter Barcelona S.A.")
    end
  end

  describe '.find' do
    let(:response_data) {
      {
        data: {
          id: "112",
          type: "company_contacts",
          attributes: {
            company_name: nil,
            legal_name: "DataCenter Barcelona S.A.",
            tax_id: "A22222222",
            email: "services@datacenterbarcelona.com",
            phone: "+34 933 789 012",
            contact_person: nil,
            is_active: true,
            owner_company_id: nil,
            created_at: "2025-09-18T10:45:11.882+02:00",
            updated_at: "2025-09-18T10:45:11.882+02:00"
          }
        }
      }
    }

    context 'when contact exists' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns transformed contact data' do
        result = CompanyContactService.find(contact_id, company_id: company_id, token: token)

        expect(result[:id]).to eq("112")
        expect(result[:company_name]).to eq("DataCenter Barcelona S.A.")
        expect(result[:legal_name]).to eq("DataCenter Barcelona S.A.")
        expect(result[:tax_id]).to eq("A22222222")
        expect(result[:email]).to eq("services@datacenterbarcelona.com")
        expect(result[:phone]).to eq("+34 933 789 012")
        expect(result[:is_active]).to be(true)
      end

      it 'handles company_name fallback to legal_name when company_name is nil' do
        result = CompanyContactService.find(contact_id, company_id: company_id, token: token)

        expect(result[:company_name]).to eq("DataCenter Barcelona S.A.")
      end
    end

    context 'when contact does not exist' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns nil and logs error' do
        # Expect error from ApiService, not CompanyContactService
        expect(Rails.logger).to receive(:error).with("Unexpected error: The requested resource was not found.")
        expect(Rails.logger).to receive(:error).with("DEBUG: CompanyContactService.find error: Unexpected error: The requested resource was not found.")

        result = CompanyContactService.find(contact_id, company_id: company_id, token: token)

        expect(result).to be_nil
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns nil and logs error' do
        # Expect error from ApiService, not CompanyContactService
        expect(Rails.logger).to receive(:error).with("Unexpected error: Server error. Please try again later.")
        expect(Rails.logger).to receive(:error).with("DEBUG: CompanyContactService.find error: Unexpected error: Server error. Please try again later.")

        result = CompanyContactService.find(contact_id, company_id: company_id, token: token)

        expect(result).to be_nil
      end
    end
  end

  describe '.create' do
    let(:params) {
      {
        legal_name: "New Contact Company",
        tax_id: "B98765432",
        email: "contact@newcompany.com",
        phone: "+34 911 123 456"
      }
    }

    let(:response_data) {
      {
        data: {
          id: "113",
          type: "company_contacts",
          attributes: params.merge(
            id: "113",
            is_active: true,
            created_at: "2025-09-18T10:45:11.882+02:00",
            updated_at: "2025-09-18T10:45:11.882+02:00"
          )
        }
      }
    }

    before do
      stub_request(:post, "#{base_url}/companies/#{company_id}/contacts")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: {
            data: {
              type: 'company_contacts',
              attributes: params
            }
          }.to_json
        )
        .to_return(status: 201, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates new company contact with proper JSON API format' do
      result = CompanyContactService.create(company_id: company_id, params: params, token: token)

      expect(result[:data][:id]).to eq("113")
      expect(result[:data][:attributes][:legal_name]).to eq("New Contact Company")
    end
  end

  describe '.update' do
    let(:params) {
      {
        email: "updated@datacenterbarcelona.com",
        phone: "+34 933 999 999"
      }
    }

    let(:response_data) {
      {
        data: {
          id: "112",
          type: "company_contacts",
          attributes: {
            legal_name: "DataCenter Barcelona S.A.",
            tax_id: "A22222222",
            email: "updated@datacenterbarcelona.com",
            phone: "+34 933 999 999",
            is_active: true,
            updated_at: "2025-09-18T10:50:00.000+02:00"
          }
        }
      }
    }

    before do
      stub_request(:put, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: {
            data: {
              type: 'company_contacts',
              attributes: params
            }
          }.to_json
        )
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates company contact with proper JSON API format' do
      result = CompanyContactService.update(company_id: company_id, contact_id: contact_id, params: params, token: token)

      expect(result[:data][:id]).to eq("112")
      expect(result[:data][:attributes][:email]).to eq("updated@datacenterbarcelona.com")
      expect(result[:data][:attributes][:phone]).to eq("+34 933 999 999")
    end
  end

  describe '.delete' do
    before do
      stub_request(:delete, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '', headers: {})
    end

    it 'deletes company contact' do
      expect {
        CompanyContactService.delete(company_id: company_id, contact_id: contact_id, token: token)
      }.not_to raise_error
    end
  end

  describe '.search' do
    it 'returns empty results as global search is not implemented' do
      result = CompanyContactService.search(query: 'test', token: token)

      expect(result[:contacts]).to eq([])
      expect(result[:total]).to eq(0)
    end
  end
end