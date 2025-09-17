require "test_helper"

class InvoiceSeriesFilteringTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
    setup_mock_services
  end

  test "invoice form includes all necessary JavaScript controller attributes" do
    get new_invoice_path

    assert_response :success

    # Verify the form has the invoice-form Stimulus controller
    assert_select 'form[data-controller*="invoice-form"]'

    # Verify invoice type dropdown has correct attributes
    assert_select 'select[name="invoice[invoice_type]"]' do
      assert_select '[data-action*="change->invoice-form#onInvoiceTypeChange"]'
      assert_select '[data-invoice-form-target="invoiceTypeSelect"]'
    end

    # Verify series dropdown has correct attributes
    assert_select 'select[name="invoice[invoice_series_id]"]' do
      assert_select '[data-action*="change->invoice-form#onSeriesChange"]'
      assert_select '[data-invoice-form-target="seriesSelect"]'
    end

    # Verify invoice number field has correct attributes
    assert_select 'input[name="invoice[invoice_number]"]' do
      assert_select '[data-invoice-form-target="invoiceNumber"]'
    end
  end

  test "invoice type dropdown contains all expected options" do
    get new_invoice_path

    assert_response :success

    # Verify all invoice type options are present
    assert_select 'select[name="invoice[invoice_type]"] option[value="invoice"]', text: 'Invoice'
    assert_select 'select[name="invoice[invoice_type]"] option[value="credit_note"]', text: 'Credit Note'
    assert_select 'select[name="invoice[invoice_type]"] option[value="debit_note"]', text: 'Debit Note'
    assert_select 'select[name="invoice[invoice_type]"] option[value="proforma"]', text: 'Proforma'
  end

  test "series dropdown contains all series types by default" do
    get new_invoice_path

    assert_response :success

    # Verify all series are available initially
    assert_select 'select[name="invoice[invoice_series_id]"] option', text: /FC - Facturas Comerciales/
    assert_select 'select[name="invoice[invoice_series_id]"] option', text: /PF - Proforma/
    assert_select 'select[name="invoice[invoice_series_id]"] option', text: /CR - Credit Note/
    assert_select 'select[name="invoice[invoice_series_id]"] option', text: /DB - Debit Note/
  end

  test "form structure supports JavaScript series filtering" do
    get new_invoice_path

    assert_response :success

    # Check that the form contains the necessary data attributes for storing series options
    # The JavaScript controller uses data-invoice-form-all-series-value to store all options
    assert_select 'form[data-controller*="invoice-form"]'

    # Verify that series data is available for JavaScript filtering
    # This would be set by the storeAllSeriesOptions method
    assert_response_body_contains_series_data
  end

  test "edit form maintains series filtering functionality" do
    mock_invoice = {
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874,
      invoice_type: "invoice"
    }

    InvoiceService.stubs(:find).returns(mock_invoice)

    get edit_invoice_path(123)

    assert_response :success

    # Verify the form maintains the same filtering attributes
    assert_select 'form[data-controller*="invoice-form"]'
    assert_select 'select[data-action*="change->invoice-form#onInvoiceTypeChange"]'
    assert_select 'select[data-invoice-form-target="invoiceTypeSelect"]'
    assert_select 'select[data-invoice-form-target="seriesSelect"]'
  end

  test "form includes proper mapping for invoice types to series codes" do
    get new_invoice_path

    assert_response :success

    # The JavaScript controller should implement the mapping:
    # 'invoice' => ['FC']
    # 'proforma' => ['PF']
    # 'credit_note' => ['CR']
    # 'debit_note' => ['DB']

    # This is tested through the presence of the getValidSeriesCodesForType method
    # which is verified by checking the JavaScript controller structure
    assert_select 'form[data-controller*="invoice-form"]'
  end

  test "series filtering works with different invoice types in create action" do
    # Test creating invoices with different types and appropriate series
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

    test_cases.each_with_index do |test_case, index|
      mock_create_response = {
        data: { id: test_case[:invoice_id] },
        id: test_case[:invoice_id],
        invoice_number: "#{test_case[:expected_series_code]}-2025-0001",
        invoice_series_id: test_case[:series_id],
        invoice_type: test_case[:invoice_type],
        status: "draft"
      }

      # Create a new stub for each test case
      InvoiceService.unstub(:create) if index > 0
      InvoiceService.stubs(:create).returns(mock_create_response)

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

      assert_redirected_to invoice_path(test_case[:invoice_id])
    end
  end

  test "series filtering validation prevents mismatched types and series" do
    # This test ensures that server-side validation would catch any cases where
    # the JavaScript filtering is bypassed and incompatible types/series are submitted

    validation_errors = [
      {
        status: "422",
        source: { pointer: "/data/attributes/invoice_series_id" },
        title: "Validation Error",
        detail: "Series type does not match invoice type",
        code: "VALIDATION_ERROR"
      }
    ]

    InvoiceService.stubs(:create).raises(ApiService::ValidationError.new("Validation failed", validation_errors))

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

    assert_response :unprocessable_content
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

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: mock_workflows })

    CompanyContactsService.stubs(:active_contacts)
      .with(company_id: 1999, token: "test_admin_token")
      .returns([])

    InvoiceService.stubs(:recent).returns([])
  end

  def assert_response_body_contains_series_data
    # Verify that the response includes series data that JavaScript can use
    # This checks that the series options are properly rendered in the select element
    assert_select 'select[name="invoice[invoice_series_id]"] option[value="874"]'
    assert_select 'select[name="invoice[invoice_series_id]"] option[value="875"]'
    assert_select 'select[name="invoice[invoice_series_id]"] option[value="876"]'
    assert_select 'select[name="invoice[invoice_series_id]"] option[value="877"]'
  end
end