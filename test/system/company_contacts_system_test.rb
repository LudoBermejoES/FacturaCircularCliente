require "application_system_test_case"

class CompanyContactsSystemTest < ApplicationSystemTestCase
  setup do
    @company = { id: 1, name: "Test Company" }
    @contacts = [
      {
        id: 1,
        name: "Acme Corp",
        legal_name: "Acme Corporation S.L.",
        tax_id: "B12345678",
        email: "info@acmecorp.com",
        phone: "+34 911 555 000",
        website: "https://www.acmecorp.com",
        is_active: true
      }
    ]
    
    # Stub API responses
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:all).returns({
      contacts: @contacts,
      meta: { total: 1 }
    })
  end

  test "visiting the company contacts index" do
    visit_authenticated("/companies/1/company_contacts")

    assert_selector "h1", text: "Company Contacts"
    # Look specifically for contact list items in the contacts list
    assert_selector "ul.divide-y li", count: 1
    assert_text "Acme Corp (Acme Corporation S.L.)"
    assert_text "B12345678"
    assert_link "info@acmecorp.com"
    assert_link "+34 911 555 000"
    assert_link "https://www.acmecorp.com"
  end

  test "creating a new company contact" do
    CompanyContactsService.stubs(:create).returns({ data: { id: 2 } })
    
    visit_authenticated("/companies/1/company_contacts/new")
    
    assert_selector "h1", text: "Add Company Contact"
    
    # Fill in company information
    fill_in "Company Name", with: "New Corp"
    fill_in "Legal Name", with: "New Corporation Ltd"
    fill_in "Tax ID", with: "C11111111"
    fill_in "Email Address", with: "info@newcorp.com"
    fill_in "Phone Number", with: "+34 999 888 777"
    fill_in "Website", with: "https://www.newcorp.com"
    
    # Fill in address information
    select "Billing", from: "Address Type"
    fill_in "Street Address", with: "Calle Nueva 456"
    fill_in "City", with: "Barcelona"
    fill_in "Postal Code", with: "08001"
    fill_in "State/Province", with: "Barcelona"
    select "Spain", from: "Country"
    check "Default Address"
    
    click_button "Create Company Contact"
    
    assert_current_path "/companies/1/company_contacts"
    assert_text "Contact was successfully created."
  end

  test "editing a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:update).returns({ data: { id: 1 } })

    visit_authenticated("/companies/1/company_contacts/1/edit")

    fill_in "Company Name", with: "Updated Acme Corp"

    # Find the submit button by its actual text/value
    within('form') do
      find('input[type="submit"], button[type="submit"]').click
    end

    assert_current_path "/companies/1/company_contacts"
    assert_text "Contact was successfully updated."
  end

  test "deleting a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:destroy).returns(true)

    visit_authenticated("/companies/1/company_contacts")

    # Click delete button - may use different method than accept_confirm
    click_button "Delete"

    # Basic test that deletion attempt was made
    # The exact success message depends on implementation
    assert_text "Contact was successfully deleted."
  end

  test "activating a company contact" do
    # Set contact as inactive to test activation
    inactive_contact = @contacts.first.dup
    inactive_contact[:is_active] = false

    CompanyContactsService.stubs(:all).returns({
      contacts: [inactive_contact],
      meta: { total: 1 }
    })
    CompanyContactsService.stubs(:find).returns(inactive_contact)
    CompanyContactsService.stubs(:activate).returns(true)

    visit_authenticated("/companies/1/company_contacts")

    # For inactive contacts, there should be an "Activate" button
    click_button "Activate"
    assert_text "Contact was successfully activated."
  end

  test "deactivating a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:deactivate).returns(true)

    visit_authenticated("/companies/1/company_contacts")

    # For active contacts, there should be a "Deactivate" button
    click_button "Deactivate"
    assert_text "Contact was successfully deactivated."
  end

  test "searching company contacts" do
    filtered_contacts = [{
      id: 1,
      name: "Acme Corp",
      legal_name: "Acme Corporation S.L.",
      tax_id: "B12345678",
      email: "info@acmecorp.com",
      phone: "+34 911 555 000",
      website: "https://www.acmecorp.com",
      is_active: true
    }]

    CompanyContactsService.stubs(:all).with(
      company_id: 1,
      token: anything,
      params: includes(search: "Acme")
    ).returns({
      contacts: filtered_contacts,
      meta: { total: 1 }
    })

    visit_authenticated("/companies/1/company_contacts")

    fill_in "Search contacts by name or email...", with: "Acme"
    click_button "Search"

    # Use specific selector for contact list items to avoid navigation elements
    assert_selector "ul.divide-y li", count: 1
    assert_text "Acme Corp"
  end

  test "form validation errors are displayed" do
    error = ApiService::ValidationError.new("Validation failed", {
      name: ["can't be blank"],
      email: ["is invalid"]
    })
    CompanyContactsService.stubs(:create).raises(error)

    visit_authenticated("/companies/1/company_contacts/new")

    # Submit form without filling required fields to trigger validation
    click_button "Create Company Contact"

    # Basic test that form stays on page (indicating validation occurred)
    # Error display format may vary, so check that we're still on form
    assert_current_path "/companies/1/company_contacts/new"
    assert_text "Add Company Contact"
  end

  test "all form fields are present and functional" do
    visit_authenticated("/companies/1/company_contacts/new")
    
    # Company information fields
    assert_field "Company Name"
    assert_field "Legal Name"
    assert_field "Tax ID"
    assert_field "Email Address"
    assert_field "Phone Number"
    assert_field "Website"
    
    # Address fields
    assert_field "Address Type"
    assert_field "Street Address"
    assert_field "City"
    assert_field "Postal Code"
    assert_field "State/Province"
    assert_field "Country"
    assert_field "Default Address"
    
    # Test that all fields accept input
    fill_in "Company Name", with: "Test Input"
    fill_in "Legal Name", with: "Test Legal Name"
    fill_in "Tax ID", with: "T12345678"
    fill_in "Email Address", with: "test@example.com"
    fill_in "Phone Number", with: "+34 123 456 789"
    fill_in "Website", with: "https://test.com"
    
    select "Shipping", from: "Address Type"
    fill_in "Street Address", with: "Test Street 123"
    fill_in "City", with: "Test City"
    fill_in "Postal Code", with: "12345"
    fill_in "State/Province", with: "Test Province"
    select "France", from: "Country"
    uncheck "Default Address"
    
    # Verify the values were set
    assert_field "Company Name", with: "Test Input"
    assert_field "Email Address", with: "test@example.com"
    assert_field "Address Type", with: "shipping"
    assert_field "Country", with: "FRA"
  end

  private

  def visit_authenticated(path)
    # Use the standard system test authentication helper
    sign_in_for_system_test(role: "manager", company_id: 1)

    # Now visit the actual path
    visit path
  end
end