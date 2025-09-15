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
    assert_selector "li", count: 1
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
    click_button "Update Company Contact"
    
    assert_current_path "/companies/1/company_contacts"
    assert_text "Contact was successfully updated."
  end

  test "deleting a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:destroy).returns(true)
    
    visit_authenticated("/companies/1/company_contacts")
    
    accept_confirm do
      click_button "Delete"
    end
    
    assert_text "Contact was successfully deleted."
  end

  test "activating a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:activate).returns(true)
    
    visit_authenticated("/companies/1/company_contacts")
    
    click_button "Activate"
    assert_text "Contact was successfully activated."
  end

  test "deactivating a company contact" do
    CompanyContactsService.stubs(:find).returns(@contacts.first)
    CompanyContactsService.stubs(:deactivate).returns(true)
    
    visit_authenticated("/companies/1/company_contacts")
    
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
    
    assert_selector "li", count: 1
    assert_text "Acme Corp"
  end

  test "form validation errors are displayed" do
    error = ApiService::ValidationError.new("Validation failed", { 
      name: ["can't be blank"],
      email: ["is invalid"]
    })
    CompanyContactsService.stubs(:create).raises(error)
    
    visit_authenticated("/companies/1/company_contacts/new")
    
    click_button "Create Company Contact"
    
    assert_text "There were errors with your submission:"
    assert_text "Name can't be blank"
    assert_text "Email is invalid"
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
    # Setup authentication
    user_data = {
      access_token: "test_token",
      user_id: 1,
      user_email: "test@example.com",
      user_name: "Test User",
      company_id: 1,
      companies: [{ "id" => 1, "name" => "Test Company", "role" => "manager" }]
    }
    
    # Stub authentication
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    # Visit login page and mock login
    visit "/login"
    
    # Mock successful login
    AuthService.stubs(:login).returns({
      access_token: user_data[:access_token],
      refresh_token: "refresh_token",
      user: {
        id: user_data[:user_id],
        email: user_data[:user_email],
        name: user_data[:user_name],
        company_id: user_data[:company_id]
      },
      company_id: user_data[:company_id],
      companies: user_data[:companies]
    })
    
    fill_in "Email", with: user_data[:user_email]
    fill_in "Password", with: "password"
    click_button "Sign In"
    
    # Now visit the actual path
    visit path
  end
end