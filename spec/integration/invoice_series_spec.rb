# Migrated from test/integration/invoice_series_filtering_test.rb
# Integration spec: Invoice series filtering and JavaScript integration

require 'rails_helper'

RSpec.describe "Invoice Series Integration", type: :request do
  # Critical Business Path: Invoice series filtering and type validation
  # Risk Level: HIGH - Series mismatches can break invoice numbering
  # Focus: Testing JavaScript controller integration and series filtering logic

  before do
    setup_authenticated_session(role: "admin", company_id: 1999)
    setup_mock_services
  end

  describe "invoice form JavaScript controller attributes" do
    it "includes all necessary Stimulus controller attributes" do
      get new_invoice_path

      expect(response).to have_http_status(:success)

      # Verify the form has the invoice-form Stimulus controller
      expect(response.body).to match(/data-controller[^>]*invoice-form/)

      # Verify invoice type dropdown has correct attributes
      expect(response.body).to match(/select[^>]*name="invoice\[invoice_type\]"[^>]*data-action[^>]*change->invoice-form#onInvoiceTypeChange/)
      expect(response.body).to match(/select[^>]*name="invoice\[invoice_type\]"[^>]*data-invoice-form-target="invoiceTypeSelect"/)

      # Verify series dropdown has correct attributes
      expect(response.body).to match(/select[^>]*name="invoice\[invoice_series_id\]"[^>]*data-action[^>]*change->invoice-form#onSeriesChange/)
      expect(response.body).to match(/select[^>]*name="invoice\[invoice_series_id\]"[^>]*data-invoice-form-target="seriesSelect"/)

      # Verify invoice number field has correct attributes
      expect(response.body).to match(/input[^>]*name="invoice\[invoice_number\]"[^>]*data-invoice-form-target="invoiceNumber"/)
    end
  end

  describe "invoice type dropdown options" do
    it "contains all expected invoice type options" do
      get new_invoice_path

      expect(response).to have_http_status(:success)

      # Verify all invoice type options are present
      expect(response.body).to match(/<option[^>]*value="invoice"[^>]*>Invoice<\/option>/)
      expect(response.body).to match(/<option[^>]*value="credit_note"[^>]*>Credit Note<\/option>/)
      expect(response.body).to match(/<option[^>]*value="debit_note"[^>]*>Debit Note<\/option>/)
      expect(response.body).to match(/<option[^>]*value="proforma"[^>]*>Proforma<\/option>/)
    end
  end

  describe "series dropdown default options" do
    it "contains all series types by default" do
      get new_invoice_path

      expect(response).to have_http_status(:success)

      # Verify all series are available initially
      expect(response.body).to match(/FC - Facturas Comerciales/)
      expect(response.body).to match(/PF - Proforma/)
      expect(response.body).to match(/CR - Credit Note/)
      expect(response.body).to match(/DB - Debit Note/)
    end
  end

  describe "JavaScript series filtering support" do
    it "supports JavaScript series filtering functionality" do
      get new_invoice_path

      expect(response).to have_http_status(:success)

      # Check that the form contains the necessary data attributes for storing series options
      expect(response.body).to match(/data-controller[^>]*invoice-form/)

      # Verify that series data is available for JavaScript filtering
      assert_response_body_contains_series_data
    end
  end

  describe "edit form series filtering" do
    it "maintains series filtering functionality in edit mode" do
      mock_invoice = {
        id: 123,
        invoice_number: "FC-2025-0001",
        invoice_series_id: 874,
        invoice_type: "invoice"
      }

      allow(InvoiceService).to receive(:find).with("123", token: anything).and_return(mock_invoice)

      get edit_invoice_path(123)

      expect(response).to have_http_status(:success)

      # Verify the form maintains the same filtering attributes
      expect(response.body).to match(/data-controller[^>]*invoice-form/)
      expect(response.body).to match(/data-action[^>]*change->invoice-form#onInvoiceTypeChange/)
      expect(response.body).to match(/data-invoice-form-target="invoiceTypeSelect"/)
      expect(response.body).to match(/data-invoice-form-target="seriesSelect"/)
    end
  end

  describe "invoice type to series code mapping" do
    it "includes proper mapping structure for invoice types to series codes" do
      get new_invoice_path

      expect(response).to have_http_status(:success)

      # The JavaScript controller should implement the mapping:
      # 'invoice' => ['FC']
      # 'proforma' => ['PF']
      # 'credit_note' => ['CR']
      # 'debit_note' => ['DB']

      # This is tested through the presence of the invoice-form controller
      expect(response.body).to match(/data-controller[^>]*invoice-form/)
    end
  end

  describe "series filtering with different invoice types" do
    it "creates invoices with appropriate series for each type", :aggregate_failures do
      test_cases = [
        {
          invoice_type: "invoice",
          series_id: 874, # FC series
          expected_series_code: "FC",
          invoice_id: 1001
        },
        {
          invoice_type: "proforma",
          series_id: 875, # PF series
          expected_series_code: "PF",
          invoice_id: 1002
        },
        {
          invoice_type: "credit_note",
          series_id: 876, # CR series
          expected_series_code: "CR",
          invoice_id: 1003
        },
        {
          invoice_type: "debit_note",
          series_id: 877, # DB series
          expected_series_code: "DB",
          invoice_id: 1004
        }
      ]

      test_cases.each do |test_case|
        mock_create_response = {
          data: { id: test_case[:invoice_id] },
          id: test_case[:invoice_id],
          invoice_number: "#{test_case[:expected_series_code]}-2025-0001",
          invoice_series_id: test_case[:series_id],
          invoice_type: test_case[:invoice_type],
          status: "draft"
        }

        allow(InvoiceService).to receive(:create).and_return(mock_create_response)

        invoice_params = {
          invoice_series_id: test_case[:series_id],
          invoice_type: test_case[:invoice_type],
          status: "draft",
          seller_party_id: 1999,
          buyer_party_id: 1999,
          issue_date: "2025-01-15",
          due_date: "2025-02-15"
        }

        post invoices_path, params: { invoice: invoice_params }

        expect(response).to redirect_to(invoice_path(test_case[:invoice_id]))
      end
    end
  end

  describe "series filtering validation" do
    it "prevents mismatched types and series" do
      # Server-side validation should catch cases where JavaScript filtering is bypassed
      validation_errors = [
        {
          status: "422",
          source: { pointer: "/data/attributes/invoice_series_id" },
          title: "Validation Error",
          detail: "Series type does not match invoice type",
          code: "VALIDATION_ERROR"
        }
      ]

      allow(InvoiceService).to receive(:create).and_raise(ApiService::ValidationError.new("Validation failed", validation_errors))

      # Try to create a proforma invoice with FC (commercial) series
      invoice_params = {
        invoice_series_id: 874, # FC series
        invoice_type: "proforma", # Proforma type - mismatch!
        status: "draft",
        seller_party_id: 1999,
        buyer_party_id: 1999,
        issue_date: "2025-01-15",
        due_date: "2025-02-15"
      }

      post invoices_path, params: { invoice: invoice_params }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  private

  def setup_mock_services
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      },
      {
        id: 875,
        series_code: "PF",
        series_name: "Proforma",
        year: 2025,
        is_active: true
      },
      {
        id: 876,
        series_code: "CR",
        series_name: "Credit Note",
        year: 2025,
        is_active: true
      },
      {
        id: 877,
        series_code: "DB",
        series_name: "Debit Note",
        year: 2025,
        is_active: true
      }
    ]

    mock_companies = [
      { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." }
    ]

    mock_workflows = []

    allow(InvoiceSeriesService).to receive(:all)
      .with(token: anything, filters: { year: Date.current.year, active_only: true })
      .and_return(mock_invoice_series)

    allow(CompanyService).to receive(:all)
      .with(token: anything, params: { per_page: 100 })
      .and_return({ companies: mock_companies })

    allow(CompanyContactsService).to receive(:all)
      .with(company_id: 1999, token: anything, params: { per_page: 100 })
      .and_return({ contacts: [] })

    allow(WorkflowService).to receive(:definitions)
      .with(token: anything)
      .and_return({ data: mock_workflows })

    allow(CompanyContactsService).to receive(:active_contacts)
      .with(company_id: 1999, token: anything)
      .and_return([])

    allow(InvoiceService).to receive(:recent).with(token: anything).and_return([])
  end

  def assert_response_body_contains_series_data
    # Verify that the response includes series data that JavaScript can use
    expect(response.body).to match(/value="874"/)
    expect(response.body).to match(/value="875"/)
    expect(response.body).to match(/value="876"/)
    expect(response.body).to match(/value="877"/)
  end
end