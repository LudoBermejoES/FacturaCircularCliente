require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
  end

  test "new action loads invoice series data" do
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      }
    ]
    
    mock_companies = [
      {
        id: 1999,
        name: "Test Company"
      }
    ]

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)
      
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })
      
    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })
      
    # Mock CompanyContactsService.active_contacts call for load_all_company_contacts
    CompanyContactsService.stubs(:active_contacts)
      .with(company_id: 1999, token: "test_admin_token")
      .returns([])

    get new_invoice_path

    assert_response :success
    assert assigns(:invoice_series)
    assert_equal mock_invoice_series, assigns(:invoice_series)
  end

  test "new action handles API service errors when loading series" do
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })
      
    # Mock CompanyContactsService.all call
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })
      
    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .raises(ApiService::ApiError, "Failed to load series")

    get new_invoice_path

    assert_response :success
    assert_equal [], assigns(:invoice_series)
  end

  test "new action renders form with correct structure" do
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      }
    ]
    
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    get new_invoice_path

    assert_response :success
    
    # Check that the form contains the series dropdown
    assert_select 'select[name="invoice[invoice_series_id]"]'
    assert_select 'option', text: /FC - Facturas Comerciales/
    
    # Check that the invoice number field is read-only
    assert_select 'input[name="invoice[invoice_number]"][readonly]'
    
    # Check for Stimulus controller data attributes
    assert_select '[data-controller*="invoice-form"]'
    assert_select '[data-invoice-form-target="seriesSelect"]'
    assert_select '[data-invoice-form-target="invoiceNumber"]'
    assert_select '[data-action*="invoice-form#onSeriesChange"]'
  end

  test "create action includes invoice_series_id in permitted parameters" do
    mock_invoice_series = [{ id: 874, series_code: "FC", series_name: "Facturas Comerciales" }]
    
    mock_companies = [
      {
        id: 1999,
        name: "Test Company"
      }
    ]
    
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })
      
    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })
      
    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)
      
    # Comprehensive stubbing to prevent WebMock errors
    CompanyContactsService.stubs(:active_contacts).returns([])

    mock_create_response = {
      data: { id: 123 },
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874,
      status: "draft"
    }

    InvoiceService.stubs(:create)
      .returns(mock_create_response)

    invoice_params = {
      invoice_series_id: 874,
      invoice_number: "FC-2025-0001",
      invoice_type: "invoice",
      status: "draft",
      seller_party_id: 1999,
      buyer_party_id: 1999,
      issue_date: "2025-01-15",
      due_date: "2025-02-15"
    }

    post invoices_path, params: { invoice: invoice_params }

    assert_redirected_to invoice_path(123)
  end

  test "create action validates required invoice_series_id" do
    mock_invoice_series = [{ id: 874, series_code: "FC", series_name: "Facturas Comerciales" }]
    
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })
      
    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })
      
    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)
      
    CompanyContactsService.stubs(:active_contacts).returns([])
    
    # Stub InvoiceService.create to raise a validation error
    validation_errors = [
      {
        status: "422",
        source: { pointer: "/data/attributes/invoice_series_id" },
        title: "Validation Error",
        detail: "Invoice series can't be blank",
        code: "VALIDATION_ERROR"
      }
    ]
    InvoiceService.stubs(:create).raises(ApiService::ValidationError.new("Validation failed", validation_errors))

    invoice_params = {
      # Missing invoice_series_id
      invoice_number: "FC-2025-0001",
      invoice_type: "invoice",
      status: "draft"
    }

    post invoices_path, params: { invoice: invoice_params }

    assert_response :unprocessable_content # Re-renders form with errors
  end

  test "edit action loads invoice series for form" do
    mock_invoice = {
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874
    }

    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales"
      }
    ]

    InvoiceService.stubs(:find)
      .returns(mock_invoice)
      
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)
      
    CompanyContactsService.stubs(:active_contacts).returns([])

    get edit_invoice_path(123)

    assert_response :success
    assert assigns(:invoice_series)
    assert_equal mock_invoice_series, assigns(:invoice_series)
  end

  test "update action handles invoice_series_id changes" do
    mock_invoice = {
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874
    }

    mock_invoice_series = [{ id: 875, series_code: "PF", series_name: "Proformas" }]

    InvoiceService.stubs(:find).returns(mock_invoice)
    
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })
      
    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })
      
    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)
      
    CompanyContactsService.stubs(:active_contacts).returns([])

    updated_invoice = mock_invoice.merge(
      invoice_series_id: 875,
      invoice_number: "PF-2025-0001"
    )

    InvoiceService.stubs(:update)
      .returns(updated_invoice)

    patch invoice_path(123), params: {
      invoice: {
        invoice_series_id: 875,
        invoice_number: "PF-2025-0001"
      }
    }

    assert_redirected_to invoice_path(123)
  end

  private

  def mock_required_services
    # Mock all required services to prevent API calls during testing
    InvoiceService.stubs(:recent).returns([])
    CompanyService.stubs(:all).returns([])
  end
end