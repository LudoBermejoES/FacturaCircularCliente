# Migrated from test/integration/critical_company_management_test.rb
# Integration spec: Critical company and address management workflows

require 'rails_helper'

RSpec.describe "Company Management Integration", type: :request do
  # Critical Business Path: Company and address management
  # Risk Level: HIGH - Company data integrity affects all invoices
  # Focus: Testing actual implemented company management features

  before do
    setup_authenticated_session(role: 'admin', company_id: 1)
    setup_company_mocks
  end

  describe "complete company management workflow" do
    it "handles full address management lifecycle" do
      # Step 1: Access companies index
      get companies_path
      expect(response).to have_http_status(:success)

      # Step 2: View specific company
      get company_path(@test_company[:id])
      expect(response).to have_http_status(:success)

      # Step 3: Test address creation (critical for invoicing)
      # Mock successful validation
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })
      allow(CompanyService).to receive(:create_address).and_return({ success: true, id: 123 })

      address_params = {
        address: "Calle Mayor 123",
        post_code: "28001",
        town: "Madrid",
        province: "Madrid",
        country_code: "ESP",
        address_type: "billing",
        is_default: true
      }

      post company_addresses_path(@test_company[:id]), params: { address: address_params }

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Address created successfully")

      # Step 4: Test address update
      allow(CompanyService).to receive(:update_address).and_return({ success: true })

      updated_address_params = address_params.merge(
        address: "Gran Vía 456",
        post_code: "28013"
      )

      patch company_address_path(@test_company[:id], 123), params: { address: updated_address_params }

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Address updated successfully")

      # Step 5: Test address deletion
      allow(CompanyService).to receive(:destroy_address).and_return({ success: true })

      delete company_address_path(@test_company[:id], 123)

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Address deleted successfully")
    end
  end

  describe "address validation prevents data corruption" do
    it "validates address data and prevents corruption" do
      get company_path(@test_company[:id])
      expect(response).to have_http_status(:success)

      # Test validation failure scenarios
      invalid_address_scenarios = [
        {
          params: { address: "", post_code: "28001" },
          expected_error: "Address"
        },
        {
          params: { address: "Valid Street", post_code: "" },
          expected_error: "Post code"
        },
        {
          params: { address: "Valid Street", post_code: "invalid_code" },
          expected_error: "Invalid postal code"
        },
        {
          params: { address: "Valid Street", post_code: "28001", country_code: "" },
          expected_error: "Country code"
        },
        {
          params: { address: "Valid Street", post_code: "28001", country_code: "ESP", address_type: "invalid" },
          expected_error: "Address type"
        }
      ]

      invalid_address_scenarios.each_with_index do |scenario, index|
        # Mock validation failure
        allow(AddressValidator).to receive(:validate_params).and_return({
          valid: false,
          errors: [scenario[:expected_error]]
        })

        post company_addresses_path(@test_company[:id]), params: { address: scenario[:params] }

        expect(response).to redirect_to(company_path(@test_company[:id]))
        expect(flash[:error]).to match(/#{Regexp.escape(scenario[:expected_error])}/i)
      end
    end
  end

  describe "company contact management integrity" do
    it "manages company contacts for invoicing buyers" do
      # Step 1: Access company contacts
      get company_company_contacts_path(@test_company[:id])
      expect(response).to have_http_status(:success)

      # Step 2: Create new company contact
      allow(CompanyContactsService).to receive(:create).and_return({
        success: true,
        data: { id: 456, company_name: "New Client S.L." }
      })

      contact_params = {
        company_name: "New Client S.L.",
        legal_name: "New Client Sociedad Limitada",
        tax_id: "B12345678",
        email: "contact@newclient.com",
        phone: "+34 91 234 5678",
        is_active: true
      }

      post company_company_contacts_path(@test_company[:id]), params: { company_contact: contact_params }

      expect(response).to redirect_to(company_company_contacts_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Contact was successfully created.")

      # Step 3: Update company contact
      allow(CompanyContactsService).to receive(:update).and_return({ success: true })

      updated_contact_params = contact_params.merge(
        company_name: "Updated Client S.L.",
        email: "updated@newclient.com"
      )

      patch company_company_contact_path(@test_company[:id], 456), params: { company_contact: updated_contact_params }

      expect(response).to redirect_to(company_company_contacts_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Contact was successfully updated.")

      # Step 4: Activate/Deactivate contact (critical for invoice buyer selection)
      allow(CompanyContactsService).to receive(:activate).and_return({ success: true })

      post activate_company_company_contact_path(@test_company[:id], 456)
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/activated/i)

      allow(CompanyContactsService).to receive(:deactivate).and_return({ success: true })

      post deactivate_company_company_contact_path(@test_company[:id], 456)
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/deactivated/i)
    end
  end

  describe "invoice series management for numbering integrity" do
    it "manages invoice series for proper numbering" do
      # Step 1: Access invoice series
      get company_invoice_series_index_path(@test_company[:id])
      expect(response).to have_http_status(:success)

      # Step 2: Create new invoice series
      allow(InvoiceSeriesService).to receive(:create).and_return({
        success: true,
        data: { id: 789, series_code: "TEST", series_name: "Test Series" }
      })

      series_params = {
        series_code: "TEST",
        series_name: "Test Series",
        year: Date.current.year,
        starting_number: 1,
        is_active: true
      }

      post company_invoice_series_index_path(@test_company[:id]), params: { invoice_series: series_params }

      expect(response).to redirect_to(company_invoice_series_index_path(@test_company[:id]))
      expect(flash[:notice]).to eq("Invoice series created successfully")

      # Step 3: Test series activation/deactivation
      allow(InvoiceSeriesService).to receive(:activate).and_return({ success: true })

      post activate_company_invoice_series_path(@test_company[:id], 789)
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/activated/i)

      allow(InvoiceSeriesService).to receive(:deactivate).and_return({ success: true })

      post deactivate_company_invoice_series_path(@test_company[:id], 789)
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/deactivated/i)

      # Step 4: Test series rollover (critical for year-end operations)
      allow(InvoiceSeriesService).to receive(:rollover).and_return({
        success: true,
        message: "Series rolled over to #{Date.current.year + 1}"
      })

      post rollover_company_invoice_series_path(@test_company[:id], 789)
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/rolled over/i)
    end
  end

  describe "company data isolation and security" do
    it "enforces data isolation between companies" do
      # Try to access another company's data
      unauthorized_company_id = @test_company[:id] + 1

      # These should be handled by authorization
      protected_paths = [
        company_path(unauthorized_company_id),
        company_company_contacts_path(unauthorized_company_id),
        company_invoice_series_index_path(unauthorized_company_id)
      ]

      protected_paths.each do |path|
        get path
        # Should either redirect with error or return 404/403
        expect(response).to have_http_status(:redirect), "Path #{path} should be protected"
        expect(flash[:error] || flash[:alert]).to be_present, "Should show authorization error for #{path}"
      end

      # Test that POST/PUT/DELETE are also protected
      post company_addresses_path(unauthorized_company_id), params: { address: {} }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to be_present

      patch company_address_path(unauthorized_company_id, 123), params: { address: {} }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to be_present
    end
  end

  describe "API error handling and user feedback" do
    it "handles API failures gracefully" do
      # Step 1: API service unavailable
      allow(CompanyService).to receive(:create_address).and_raise(ApiService::ApiError.new("Service unavailable"))

      post company_addresses_path(@test_company[:id]), params: {
        address: {
          address: "Test Street",
          post_code: "28001",
          town: "Madrid",
          province: "Madrid",
          country_code: "ESP",
          address_type: "billing"
        }
      }

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:error]).to match(/Service unavailable/i)

      # Step 2: Network timeout
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })
      allow(CompanyService).to receive(:create_address).and_raise(Timeout::Error.new("Connection timeout"))

      post company_addresses_path(@test_company[:id]), params: {
        address: {
          address: "Test Street 2",
          post_code: "28001"
        }
      }

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:error]).to match(/Network timeout.*try again/i)

      # Step 3: Validation error from API
      allow(CompanyService).to receive(:create_address).and_raise(ApiService::ValidationError.new(["Street address cannot be blank"]))

      post company_addresses_path(@test_company[:id]), params: { address: {} }

      expect(response).to redirect_to(company_path(@test_company[:id]))
      expect(flash[:error]).to match(/Validation failed.*Street address/i)
    end
  end

  private

  def setup_company_mocks
    @test_company = {
      id: 1,
      name: "Tech Solutions Inc.",
      legal_name: "Tech Solutions Incorporated"
    }

    @mock_companies = [@test_company]

    @mock_contacts = [
      {
        id: 101,
        company_name: "Existing Client S.L.",
        legal_name: "Existing Client Sociedad Limitada",
        tax_id: "B87654321",
        is_active: true
      }
    ]

    @mock_series = [
      {
        id: 74,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: Date.current.year,
        is_active: true
      }
    ]

    # Setup service stubs with token parameter
    allow(CompanyService).to receive(:all).with(token: anything).and_return({ companies: @mock_companies })
    allow(CompanyService).to receive(:find).with(anything, token: anything).and_return(@test_company)
    allow(CompanyService).to receive(:addresses).with(anything, token: anything).and_return([])
    allow(CompanyContactsService).to receive(:all).with(token: anything).and_return({ contacts: @mock_contacts })
    allow(InvoiceSeriesService).to receive(:all).with(token: anything).and_return(@mock_series)
  end
end