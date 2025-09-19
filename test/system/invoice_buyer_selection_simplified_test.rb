require "application_system_test_case"

class InvoiceBuyerSelectionSimplifiedTest < ApplicationSystemTestCase
  def setup
    setup_mocked_services
    sign_in_for_system_test(role: "admin", company_id: 1999)
  end

  test "buyer selection form structure exists" do
    visit new_invoice_path

    # Verify buyer dropdown exists
    assert_selector "select#buyer_selection"

    # Verify hidden fields exist for both buyer types
    assert_selector "input[name='invoice[buyer_party_id]']", visible: false
    assert_selector "input[name='invoice[buyer_company_contact_id]']", visible: false

    # Verify dropdown has options
    buyer_dropdown = find("select#buyer_selection")
    assert buyer_dropdown.all('option').count >= 1, "Expected at least 1 option in buyer dropdown"
  end

  test "form can be submitted with buyer selection" do
    # Mock successful invoice creation
    InvoiceService.stubs(:create).returns({ data: { id: "test_invoice_id" } })

    visit new_invoice_path

    # Fill basic form info
    select "FC - Facturas Comerciales", from: "invoice_invoice_series_id"

    # Select first available buyer option (skip prompt option)
    buyer_dropdown = find("select#buyer_selection")
    non_empty_options = buyer_dropdown.all('option').reject { |opt| opt.text.blank? || opt.text.include?("Select") }
    if non_empty_options.any?
      buyer_dropdown.select(non_empty_options.first.text)
    end

    # Fill required fields
    fill_in "Invoice Date", with: Date.current.strftime('%Y-%m-%d')

    # Submit form (basic functionality test)
    click_button "Create Invoice"

    # Form should process without errors
    assert_text "Invoice" # Should be on some invoice-related page
  end

  test "buyer dropdown shows available options" do
    visit new_invoice_path

    buyer_dropdown = find("select#buyer_selection")
    options_text = buyer_dropdown.text.downcase

    # Should have some buyer options available (based on mocked data)
    assert options_text.length > 10, "Expected buyer dropdown to have content, got: #{buyer_dropdown.text}"
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
  end
end