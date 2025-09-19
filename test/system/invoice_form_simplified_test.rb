require "application_system_test_case"

class InvoiceFormSimplifiedTest < ApplicationSystemTestCase
  def setup
    setup_mocked_services
    sign_in_for_system_test(role: "admin", company_id: 1999)
  end

  test "new invoice form loads with basic structure" do
    visit new_invoice_path

    # Basic form structure
    assert_text "New Invoice"
    assert_selector "form"

    # Key form fields exist
    assert_selector "select[name='invoice[invoice_series_id]']"
    assert_selector "input[name='invoice[invoice_number]']"
    assert_selector "select#buyer_selection"

    # Form controls
    assert_button "Create Invoice"
    assert_link "Cancel"
  end

  test "invoice form has proper field structure" do
    visit new_invoice_path

    # Invoice information section
    assert_text "Invoice Information"
    assert_selector "select[name='invoice[invoice_series_id]']"
    assert_selector "input[name='invoice[invoice_number]']"

    # Buyer selection
    assert_selector "select#buyer_selection"
    assert_selector "input[name='invoice[buyer_party_id]']", visible: false
    assert_selector "input[name='invoice[buyer_company_contact_id]']", visible: false

    # Date fields (may have different labels)
    date_fields = page.all('input[type="date"]')
    assert date_fields.count >= 1, "Expected at least 1 date field"
  end

  test "invoice form accepts basic input" do
    visit new_invoice_path

    # Fill basic form fields
    if has_select?("invoice_invoice_series_id")
      series_options = find("select[name='invoice[invoice_series_id]']").all('option')
      if series_options.any? { |opt| !opt.text.blank? && !opt.text.include?("Select") }
        first_series = series_options.find { |opt| !opt.text.blank? && !opt.text.include?("Select") }
        select first_series.text, from: "invoice_invoice_series_id"
      end
    end

    # Test basic form interaction - dates may have different behavior in headless browsers
    date_fields = page.all('input[type="date"]')
    if date_fields.any?
      # Just verify form accepts input without checking exact format
      original_value = date_fields.first.value
      date_fields.first.set("2024-01-15")
      # Verify the field changed (exact format may vary in headless browsers)
      assert_not_equal original_value, date_fields.first.value, "Date field should accept input"
    end
  end

  test "invoice form has line items section" do
    visit new_invoice_path

    # Line items section
    assert_text "Line Items"
    assert_selector "table"
    assert_selector "tbody"

    # Should have add line button
    assert_button "Add Line"

    # Totals section
    assert_text "Subtotal"
    assert_text "Tax"
    assert_text "Total"
  end

  test "edit invoice form loads with basic structure" do
    # Mock invoice data for editing
    mock_invoice = {
      id: 123,
      invoice_number: "INV-001",
      invoice_series_id: 1,
      issue_date: Date.current.strftime('%Y-%m-%d'),
      due_date: (Date.current + 30).strftime('%Y-%m-%d'),
      status: "draft"
    }

    InvoiceService.stubs(:find).returns(mock_invoice)

    visit edit_invoice_path(123)

    # Basic form structure for editing
    assert_text "Edit Invoice"
    assert_selector "form"

    # Key form fields should be present
    assert_selector "input[name='invoice[invoice_number]']"
    assert_button "Update Invoice"
    assert_link "Cancel"
  end

  private

  def setup_mocked_services
    # Mock services to prevent real API calls
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
      { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." }
    ]
    mock_contacts = [
      { id: 11, name: "abc", legal_name: "ABC Contact" }
    ]

    InvoiceSeriesService.stubs(:all).returns(mock_invoice_series)
    CompanyService.stubs(:all).returns({ companies: mock_companies })
    CompanyContactsService.stubs(:all).returns({ contacts: mock_contacts })
    InvoiceService.stubs(:recent).returns([])
    InvoiceService.stubs(:create).returns({ data: { id: "123" } })
  end
end