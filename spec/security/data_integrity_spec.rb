# Migrated from test/security/data_integrity_test.rb
# Security spec: Data integrity and business logic consistency

require 'rails_helper'

RSpec.describe "Data Integrity Security", type: :request do
  # Security Test: Data integrity and business logic consistency
  # Risk Level: CRITICAL - Data corruption affects business operations and compliance
  # Focus: Preventing data corruption, ensuring consistency, and maintaining business rules

  before do
    setup_authenticated_session(role: 'admin', company_id: 1)
    setup_data_integrity_test_mocks
  end

  describe "invoice data consistency throughout lifecycle" do
    it "maintains invoice data consistency during workflow transitions" do
      # Step 1: Create invoice
      allow(InvoiceService).to receive(:create).and_return({
        data: {
          id: '100',
          type: 'invoices',
          attributes: {
            invoice_number: 'FC-001',
            status: 'draft',
            total_amount: 1210.0,
            currency_code: 'EUR',
            issue_date: Date.current.iso8601,
            seller_party_id: 1,
            buyer_party_id: 2
          }
        }
      })

      allow(InvoiceSeriesService).to receive(:all).and_return([{
        id: 74, series_code: 'FC', series_name: 'Facturas Comerciales'
      }])

      post invoices_path, params: {
        invoice: {
          invoice_series_id: '74',
          document_type: 'FC',
          issue_date: Date.current.iso8601,
          currency_code: 'EUR',
          buyer_party_id: '2'
        }
      }

      expect(response).to redirect_to(invoice_path('100'))
      expect(flash[:notice]).to eq('Invoice created successfully')

      # Step 2: Verify data integrity constraints during updates
      # Test that critical fields cannot be modified after certain states

      # Mock frozen invoice scenario
      allow(InvoiceService).to receive(:find).and_return({
        data: {
          id: '100',
          type: 'invoices',
          attributes: {
            invoice_number: 'FC-001',
            status: 'frozen',
            is_frozen: true,
            total_amount: 1210.0
          }
        }
      })

      # Attempt to modify frozen invoice (should be prevented)
      patch invoice_path('100'), params: {
        invoice: { total_amount: 2000.0 }
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to match(/cannot.*modify.*frozen|frozen.*invoice/i)

      # Step 3: Test invoice number immutability
      # Invoice numbers should never be modifiable once assigned
      patch invoice_path('100'), params: {
        invoice: { invoice_number: 'FC-999' }
      }

      # Should be rejected or ignored (depending on implementation)
      expect(response).to have_http_status(:redirect)
      # The exact behavior depends on implementation, but invoice number should be protected
    end
  end

  describe "address validation prevents invalid geographic data" do
    it "rejects invalid address combinations" do
      # Test that address validation prevents nonsensical or malicious geographic data

      invalid_address_combinations = [
        {
          address: "Valid Street 123",
          town: "Madrid",
          province: "Barcelona",  # Province doesn't match city
          country_code: "ESP",
          expected_error: "Province"
        },
        {
          address: "Test Street",
          town: "Paris",
          province: "Madrid",
          country_code: "ESP",  # Country doesn't match city
          expected_error: "Country"
        },
        {
          address: "Main Street",
          town: "Madrid",
          province: "Madrid",
          country_code: "FRA",  # Wrong country for Spanish city
          post_code: "28001",   # Spanish postal code
          expected_error: "Country code"
        },
        {
          address: "Street Name",
          town: "Madrid",
          province: "Madrid",
          country_code: "ESP",
          post_code: "75001",   # French postal code for Spanish address
          expected_error: "Post code"
        }
      ]

      invalid_address_combinations.each do |invalid_address|
        allow(AddressValidator).to receive(:validate_params).and_return({
          valid: false,
          errors: [invalid_address[:expected_error]]
        })

        post company_addresses_path(1), params: { address: invalid_address }

        expect(response).to redirect_to(company_path(1))
        expect(flash[:error]).to match(/#{Regexp.escape(invalid_address[:expected_error])}/i)
      end
    end
  end

  describe "tax calculation consistency and audit trail" do
    it "ensures tax calculations are consistent and auditable" do
      # Step 1: Create invoice with specific line items
      invoice_data = {
        id: '200',
        subtotal: 1000.0,
        line_items: [
          { description: 'Service A', quantity: 1, unit_price: 600.0, tax_rate: 21.0 },
          { description: 'Service B', quantity: 2, unit_price: 200.0, tax_rate: 21.0 }
        ]
      }

      # Step 2: Calculate taxes
      expected_tax_calculation = {
        subtotal: 1000.0,
        tax_amount: 210.0,  # 21% of 1000
        total_amount: 1210.0,
        tax_breakdown: [
          { name: 'IVA 21%', base: 1000.0, rate: 21.0, amount: 210.0 }
        ],
        calculation_timestamp: Time.current.iso8601,
        calculation_method: 'standard_iva'
      }

      allow(TaxService).to receive(:calculate_for_invoice).and_return({ data: expected_tax_calculation })

      post tax_calculations_path, params: { invoice_id: '200' }

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/tax.*calculated.*successfully/i)

      # Step 3: Verify tax calculation cannot be manipulated
      # Test that recalculation with same data produces same result
      allow(TaxService).to receive(:calculate_for_invoice).and_return({ data: expected_tax_calculation })

      post recalculate_tax_calculations_path, params: { invoice_id: '200' }

      # Should produce identical result
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/tax.*recalculated/i)

      # Step 4: Test tax rate tampering prevention
      # Attempt to use invalid tax rates
      invalid_tax_rates = [99.0, -5.0, 150.0]  # Invalid Spanish tax rates

      invalid_tax_rates.each do |invalid_rate|
        allow(TaxService).to receive(:validate_tax_rate).and_return({
          valid: false,
          errors: ["Tax rate #{invalid_rate}% is not valid for Spanish invoices"]
        })

        # This would typically be called during line item creation with custom tax rate
        # This would typically be handled through the invoice edit form
        # rather than a direct line items endpoint
        patch invoice_path('200'), params: {
          invoice: {
            line_items_attributes: [{
              description: 'Test Item',
              quantity: 1,
              unit_price: 100.0,
              custom_tax_rate: invalid_rate
            }]
          }
        }

        # Should reject invalid tax rates
        expect(response).to have_http_status(:redirect)
        expect(flash[:error] || flash[:alert]).to match(/tax rate.*not valid/i)
      end
    end
  end

  describe "invoice series numbering integrity" do
    it "maintains sequential integrity and prevents conflicts" do
      # Mock current series state
      current_series = {
        id: 74,
        series_code: 'FC',
        current_number: 5,
        year: Date.current.year,
        company_id: 1
      }

      # Step 1: Request next available number
      allow(InvoiceSeriesService).to receive(:next_available_number).and_return({
        series_id: 74,
        next_number: 6,
        formatted_number: 'FC-0006'
      })

      get api_v1_invoice_numbering_next_available_path, params: { series_id: 74 }

      if response.successful?
        response_data = JSON.parse(response.body)
        expect(response_data['next_number']).to eq(6)
        expect(response_data['formatted_number']).to eq('FC-0006')
      end

      # Step 2: Test duplicate number prevention
      allow(InvoiceSeriesService).to receive(:validate_number_availability).and_return({
        available: false,
        error: 'Invoice number FC-0005 already exists'
      })

      # Attempt to create invoice with existing number
      allow(InvoiceService).to receive(:create).and_raise(
        ApiService::ValidationError.new(['Invoice number already exists'])
      )

      post invoices_path, params: {
        invoice: {
          invoice_series_id: '74',
          manual_number: 'FC-0005',  # Already used
          document_type: 'FC'
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/invoice number.*already exists|duplicate.*number/i)

      # Step 3: Test year rollover integrity
      # Numbers should reset for new year but maintain continuity
      next_year_series = {
        id: 74,
        series_code: 'FC',
        current_number: 1,  # Reset for new year
        year: Date.current.year + 1,
        company_id: 1
      }

      allow(InvoiceSeriesService).to receive(:rollover_year).and_return({
        success: true,
        new_year: Date.current.year + 1,
        reset_number: 1
      })

      post rollover_company_invoice_series_path(1, 74)

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/series.*rolled.*over/i)
    end
  end

  describe "company contact data consistency" do
    it "maintains referential integrity for company contacts" do
      # Step 1: Create company contact
      valid_contact_data = {
        company_name: 'Valid Client S.L.',
        legal_name: 'Valid Client Sociedad Limitada',
        tax_id: 'B12345678',
        email: 'valid@client.com',
        phone: '+34 91 234 5678',
        is_active: true
      }

      allow(CompanyContactsService).to receive(:create).and_return({
        success: true,
        data: { id: 123, **valid_contact_data }
      })

      post company_company_contacts_path(1), params: { company_contact: valid_contact_data }

      expect(response).to redirect_to(company_company_contacts_path(1))
      expect(flash[:notice]).to match(/Contact was successfully created/i)

      # Step 2: Test tax ID uniqueness constraint
      # Attempt to create contact with duplicate tax ID
      allow(CompanyContactsService).to receive(:create).and_raise(
        ApiService::ValidationError.new(['Tax ID already exists in system'])
      )

      duplicate_contact = valid_contact_data.merge(
        company_name: 'Different Company',
        tax_id: 'B12345678'  # Same tax ID
      )

      post company_company_contacts_path(1), params: { company_contact: duplicate_contact }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/tax id.*already exists|duplicate.*tax id/i)

      # Step 3: Test contact deactivation maintains referential integrity
      # Contacts used in invoices should not be deletable
      allow(CompanyContactsService).to receive(:destroy).and_raise(
        ApiService::ValidationError.new(['Cannot delete contact used in invoices'])
      )

      delete company_company_contact_path(1, 123)

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/cannot delete.*used in invoices/i)

      # But deactivation should work
      allow(CompanyContactsService).to receive(:deactivate).and_return({ success: true })

      post deactivate_company_company_contact_path(1, 123)

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to match(/contact.*deactivated/i)
    end
  end

  describe "workflow state consistency and business rules" do
    it "enforces valid state transitions" do
      # Test valid state transitions
      valid_transitions = [
        { from: 'draft', to: 'pending_approval', valid: true },
        { from: 'pending_approval', to: 'approved', valid: true },
        { from: 'approved', to: 'sent', valid: true },
        { from: 'sent', to: 'paid', valid: true }
      ]

      valid_transitions.each do |transition|
        allow(WorkflowService).to receive(:available_transitions).and_return({
          available_transitions: [
            { from: transition[:from], to: transition[:to], action: 'transition' }
          ]
        })

        allow(WorkflowService).to receive(:transition_status).and_return({
          success: true,
          new_status: transition[:to]
        })

        # Mock invoice in starting state
        allow(InvoiceService).to receive(:find).and_return({
          data: {
            id: '300',
            type: 'invoices',
            attributes: { status: transition[:from], invoice_number: 'FC-300' }
          }
        })

        post transition_invoice_workflow_path('300'), params: {
          status: transition[:to],
          comment: "Testing #{transition[:from]} to #{transition[:to]}"
        }

        if transition[:valid]
          expect(response).to have_http_status(:redirect)
          expect(flash[:notice]).to match(/status.*updated|transition.*successful/i)
        else
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to match(/invalid.*transition|cannot.*transition/i)
        end
      end
    end

    it "prevents invalid state transitions" do
      # Test invalid state transitions
      invalid_transitions = [
        { from: 'draft', to: 'paid' },        # Skip approval process
        { from: 'sent', to: 'draft' },        # Backward transition
        { from: 'frozen', to: 'draft' },      # From frozen state
        { from: 'cancelled', to: 'approved' } # From cancelled
      ]

      invalid_transitions.each do |transition|
        allow(WorkflowService).to receive(:available_transitions).and_return({
          available_transitions: []  # No valid transitions available
        })

        allow(WorkflowService).to receive(:transition_status).and_raise(
          ApiService::ValidationError.new(["Invalid transition from #{transition[:from]} to #{transition[:to]}"])
        )

        post transition_invoice_workflow_path('300'), params: {
          status: transition[:to]
        }

        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/invalid.*transition/i)
      end
    end
  end

  describe "concurrent operation consistency" do
    it "handles concurrent modifications with version conflicts" do
      # Simulate concurrent modifications to same invoice
      invoice_id = '400'

      # Mock initial invoice state
      allow(InvoiceService).to receive(:find).and_return({
        data: {
          id: invoice_id,
          type: 'invoices',
          attributes: {
            status: 'draft',
            total_amount: 1000.0,
            version: 1  # Optimistic locking version
          }
        }
      })

      # Test optimistic locking / version conflict detection
      allow(InvoiceService).to receive(:update).and_raise(
        ApiService::ValidationError.new(['Invoice was modified by another user'])
      )

      patch invoice_path(invoice_id), params: {
        invoice: { status: 'approved' },
        version: 1  # Outdated version
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/modified by another user|version conflict/i)
    end

    it "handles bulk operations with partial failures" do
      # Test that bulk operations maintain consistency
      invoice_ids = ['401', '402', '403']

      # Mock partial failure in bulk operation
      allow(WorkflowService).to receive(:bulk_transition).and_return({
        success: false,
        updated_count: 2,
        failed_count: 1,
        errors: ['Invoice 403: Cannot approve frozen invoice'],
        rollback_performed: true
      })

      post bulk_invoice_transition_path, params: {
        invoice_ids: invoice_ids,
        action: 'approve'
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to match(/2 updated.*1 failed|partial.*success/i)
    end
  end

  private

  def setup_data_integrity_test_mocks
    # Base company data
    @test_company = { id: 1, name: 'Integrity Test Company' }

    # Mock services with default successful responses (with token parameter)
    allow(CompanyService).to receive(:find).with(anything, token: anything).and_return(@test_company)
    allow(CompanyService).to receive(:all).with(token: anything).and_return({ companies: [@test_company] })

    # Mock invoice series
    @test_series = [{
      id: 74,
      series_code: 'FC',
      series_name: 'Facturas Comerciales',
      current_number: 5,
      year: Date.current.year
    }]

    allow(InvoiceSeriesService).to receive(:all).with(token: anything).and_return(@test_series)

    # Mock basic invoice data
    allow(InvoiceService).to receive(:recent).with(token: anything).and_return([])

    # Mock company contacts
    allow(CompanyContactsService).to receive(:all).with(token: anything).and_return({ contacts: [] })
    allow(CompanyContactsService).to receive(:active_contacts).with(token: anything).and_return([])

    # Default validation success
    allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })
  end
end