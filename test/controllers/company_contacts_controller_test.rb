require "test_helper"

class CompanyContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = { id: 1, name: "Test Company" }
    @mock_contacts = [
      {
        id: 1,
        name: "Acme Corp",
        legal_name: "Acme Corporation S.L.",
        tax_id: "B12345678",
        email: "info@acmecorp.com",
        phone: "+34 911 555 000",
        website: "https://www.acmecorp.com",
        is_active: true
      },
      {
        id: 2,
        name: "Beta LLC",
        legal_name: "Beta Limited Liability Company",
        tax_id: "C87654321",
        email: "contact@betallc.com",
        phone: "+34 922 444 111",
        website: "https://www.betallc.com",
        is_active: true
      }
    ]
    
    @new_contact_params = {
      name: "New Contact Corp",
      legal_name: "New Contact Corporation Ltd",
      tax_id: "D99999999",
      email: "info@newcontact.com",
      phone: "+34 933 777 888",
      website: "https://www.newcontact.com",
      addresses: [
        {
          address_type: "billing",
          street_address: "Calle Test 123",
          city: "Madrid",
          postal_code: "28013",
          state_province: "Madrid",
          country_code: "ESP",
          is_default: true
        }
      ]
    }
  end

  test "should get index" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:all).returns({
      contacts: @mock_contacts,
      meta: { total: 2 }
    })
    
    get company_company_contacts_url(1)
    assert_response :success
    assert_select "h1", text: "Company Contacts"
    assert_select "ul.divide-y li", count: 2 # Should show 2 contacts
  end

  test "should show new" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    
    get new_company_company_contact_url(1)
    assert_response :success
    assert_select "h1", text: "Add Company Contact"
    assert_select "input[name='company_contact[name]']"
    assert_select "input[name='company_contact[legal_name]']"
    assert_select "input[name='company_contact[tax_id]']"
    assert_select "input[name='company_contact[email]']"
    assert_select "input[name='company_contact[phone]']"
    assert_select "input[name='company_contact[website]']"
    
    # Check address fields
    assert_select "select[name='company_contact[addresses[0][address_type]]']"
    assert_select "textarea[name='company_contact[addresses[0][street_address]]']"
    assert_select "input[name='company_contact[addresses[0][city]]']"
    assert_select "input[name='company_contact[addresses[0][postal_code]]']"
    assert_select "input[name='company_contact[addresses[0][state_province]]']"
    assert_select "select[name='company_contact[addresses[0][country_code]]']"
    assert_select "input[name='company_contact[addresses[0][is_default]]']"
  end

  test "should create company_contact" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:create).returns({ data: { id: 3 } })
    
    post company_company_contacts_url(1), params: { company_contact: @new_contact_params }
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact was successfully created.", flash[:notice]
  end

  test "should handle validation errors on create" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    
    # Mock validation error
    error = ApiService::ValidationError.new("Validation failed", { name: ["can't be blank"] })
    CompanyContactsService.stubs(:create).raises(error)
    
    post company_company_contacts_url(1), params: { 
      company_contact: { name: "", email: "invalid" } 
    }
    
    assert_response :unprocessable_content
    assert_select "h3", text: "There were errors with your submission:"
  end

  test "should show edit" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).returns(@mock_contacts.first)
    
    get edit_company_company_contact_url(1, 1)
    assert_response :success
    assert_select "input[value='#{@mock_contacts.first[:name]}']"
  end

  test "should update company_contact" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).returns(@mock_contacts.first)
    CompanyContactsService.stubs(:update).returns({ data: { id: 1 } })
    
    patch company_company_contact_url(1, 1), params: { 
      company_contact: { name: "Updated Name" } 
    }
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact was successfully updated.", flash[:notice]
  end

  test "should destroy company_contact" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).returns(@mock_contacts.first)
    CompanyContactsService.stubs(:destroy).returns(true)
    
    delete company_company_contact_url(1, 1)
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact was successfully deleted.", flash[:notice]
  end

  test "should activate company_contact" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).returns(@mock_contacts.first)
    CompanyContactsService.stubs(:activate).returns(true)
    
    post activate_company_company_contact_url(1, 1)
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact was successfully activated.", flash[:notice]
  end

  test "should deactivate company_contact" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).returns(@mock_contacts.first)
    CompanyContactsService.stubs(:deactivate).returns(true)
    
    post deactivate_company_company_contact_url(1, 1)
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact was successfully deactivated.", flash[:notice]
  end

  test "should require authentication" do
    get company_company_contacts_url(1)
    assert_redirected_to login_path
  end

  test "should handle company not found" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).raises(ApiService::ApiError.new("Company not found"))
    
    get company_company_contacts_url(999)
    
    assert_redirected_to companies_path
    follow_redirect!
    assert_equal "Company not found: Company not found", flash[:alert]
  end

  test "should handle contact not found" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:find).raises(ApiService::ApiError.new("Contact not found"))
    
    get edit_company_company_contact_url(1, 999)
    
    assert_redirected_to company_company_contacts_url(1)
    follow_redirect!
    assert_equal "Contact not found: Contact not found", flash[:alert]
  end

  test "should filter and search contacts" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    CompanyService.stubs(:find).returns(@company)
    CompanyContactsService.stubs(:all).with(
      company_id: 1,
      token: "test_manager_token",
      params: { page: 1, per_page: 25, search: "Acme" }
    ).returns({
      contacts: [@mock_contacts.first],
      meta: { total: 1 }
    })
    
    get company_company_contacts_url(1), params: { search: "Acme" }
    
    assert_response :success
    assert_select "ul.divide-y li", count: 1 # Should show 1 filtered contact
  end
end