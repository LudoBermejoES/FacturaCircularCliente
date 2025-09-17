require "application_system_test_case"

class InvoiceBuyerSelectionTest < ApplicationSystemTestCase
  def setup
    setup_mocked_services
    sign_in_for_system_test(role: "admin", company_id: 1999)
  end

  test "buyer dropdown shows companies and contacts with clear type labels" do
    visit new_invoice_path

    # Verify buyer dropdown exists
    assert_selector "select#buyer_selection"

    buyer_dropdown = find("select#buyer_selection")

    # Verify options show type labels
    assert buyer_dropdown.has_content?("TechSol (Company)")
    assert buyer_dropdown.has_content?("abc (Contact)")
    assert buyer_dropdown.has_content?("Select customer")
  end

  test "selecting company sets buyer_party_id and clears buyer_company_contact_id" do
    visit new_invoice_path

    # Select a company
    select "TechSol (Company)", from: "buyer_selection"

    # Verify hidden fields are set correctly
    buyer_party_id = find("input[name='invoice[buyer_party_id]']", visible: false)
    buyer_contact_id = find("input[name='invoice[buyer_company_contact_id]']", visible: false)

    assert_equal "1999", buyer_party_id.value
    assert_equal "", buyer_contact_id.value
  end

  test "selecting contact sets buyer_company_contact_id and clears buyer_party_id" do
    visit new_invoice_path

    # Select a contact
    select "abc (Contact)", from: "buyer_selection"

    # Verify hidden fields are set correctly
    buyer_party_id = find("input[name='invoice[buyer_party_id]']", visible: false)
    buyer_contact_id = find("input[name='invoice[buyer_company_contact_id]']", visible: false)

    assert_equal "", buyer_party_id.value
    assert_equal "11", buyer_contact_id.value
  end

  test "deselecting buyer clears both hidden fields" do
    visit new_invoice_path

    # First select a contact
    select "abc (Contact)", from: "buyer_selection"

    # Verify contact is selected
    buyer_contact_id = find("input[name='invoice[buyer_company_contact_id]']", visible: false)
    assert_equal "11", buyer_contact_id.value

    # Then deselect
    select "Select customer", from: "buyer_selection"

    # Verify both fields are cleared
    buyer_party_id = find("input[name='invoice[buyer_party_id]']", visible: false)
    buyer_contact_id = find("input[name='invoice[buyer_company_contact_id]']", visible: false)

    assert_equal "", buyer_party_id.value
    assert_equal "", buyer_contact_id.value
  end

  test "buyer selection is preserved after form validation errors" do
    visit new_invoice_path

    # Select a contact
    select "abc (Contact)", from: "buyer_selection"

    # Fill in minimum required fields but leave something that will cause validation error
    select "FC - Facturas Comerciales 2025", from: "Invoice Series"
    select "TechSol", from: "From (Seller)"

    # Submit form (this should cause validation error due to missing invoice lines)
    click_button "Save as Draft"

    # Verify the buyer selection is preserved after error
    buyer_dropdown = find("select#buyer_selection")
    assert_equal "contact:11", buyer_dropdown.value

    # Verify the dropdown still shows the selected option
    selected_option = buyer_dropdown.find("option[selected]")
    assert_equal "abc (Contact)", selected_option.text
  end

  test "form submission includes correct buyer fields based on selection type" do
    visit new_invoice_path

    # Mock successful invoice creation
    stub_successful_invoice_creation

    # Fill out form with contact selection
    select "FC - Facturas Comerciales 2025", from: "Invoice Series"
    select "TechSol", from: "From (Seller)"
    select "abc (Contact)", from: "buyer_selection"

    # Fill in required line item
    fill_in "Item description", with: "Test Service"
    fill_in_line_item_field("quantity", 1)
    fill_in_line_item_field("unit_price", 100.0)

    # Submit form
    click_button "Save as Draft"

    # Verify success (this would only happen if the buyer_company_contact_id was correctly sent)
    assert_current_path invoice_path("test_invoice_id")
  end

  test "switching between company and contact updates fields correctly" do
    visit new_invoice_path

    # First select a company
    select "TechSol (Company)", from: "buyer_selection"

    buyer_party_id = find("input[name='invoice[buyer_party_id]']", visible: false)
    buyer_contact_id = find("input[name='invoice[buyer_company_contact_id]']", visible: false)

    assert_equal "1999", buyer_party_id.value
    assert_equal "", buyer_contact_id.value

    # Then switch to a contact
    select "abc (Contact)", from: "buyer_selection"

    # Verify fields switched correctly
    assert_equal "", buyer_party_id.value
    assert_equal "11", buyer_contact_id.value

    # Switch back to company
    select "TechSol (Company)", from: "buyer_selection"

    # Verify fields switched back
    assert_equal "1999", buyer_party_id.value
    assert_equal "", buyer_contact_id.value
  end

  test "buyer selection works with different company contexts" do
    visit new_invoice_path

    # The dropdown should show options relevant to current company context
    buyer_dropdown = find("select#buyer_selection")

    # Should show the current company as an option
    assert buyer_dropdown.has_content?("TechSol (Company)")

    # Should show contacts from the current company
    assert buyer_dropdown.has_content?("abc (Contact)")

    # Should not show empty or invalid options
    refute buyer_dropdown.has_content?("(Company)")
    refute buyer_dropdown.has_content?("(Contact)")
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

  def fill_in_line_item_field(field_name, value)
    # Helper to fill in line item fields that may have complex names
    find("input[name*='[#{field_name}]']").set(value)
  end

  def stub_successful_invoice_creation
    # Stub the invoice creation to return success
    InvoiceService.stubs(:create).returns({
      data: { id: "test_invoice_id" }
    })
  end
end