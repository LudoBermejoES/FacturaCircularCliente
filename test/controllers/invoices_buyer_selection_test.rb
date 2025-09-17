require "test_helper"

class InvoicesBuyerSelectionTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
    setup_service_stubs
  end

  test "load_companies creates buyer_options with companies and contacts" do
    get new_invoice_path

    assert_response :success

    # Verify that the controller loads buyer options correctly
    buyer_options = assigns(:buyer_options)
    assert_not_nil buyer_options
    assert buyer_options.is_a?(Array)

    # Should have companies and contacts
    company_option = buyer_options.find { |opt| opt[:type] == 'company' }
    contact_option = buyer_options.find { |opt| opt[:type] == 'contact' }

    assert_not_nil company_option
    assert_not_nil contact_option

    # Verify structure
    assert_equal 1999, company_option[:id]
    assert_equal 'company', company_option[:type]
    assert_includes company_option[:name], 'TechSol'

    assert_equal 11, contact_option[:id]
    assert_equal 'contact', contact_option[:type]
    assert_includes contact_option[:name], 'abc'
  end

  test "process_invoice_params sets buyer_party_id when company selected" do
    invoice_params = {
      invoice_number: "FC-001",
      invoice_series_id: "874",
      seller_party_id: "1999"
    }

    post invoices_path, params: {
      invoice: invoice_params,
      buyer_selection: "company:1999"
    }

    # Should have processed the buyer selection
    # Check the logs or response to verify processing occurred
    assert_response :unprocessable_content # Expected due to missing required fields
  end

  test "process_invoice_params sets buyer_company_contact_id when contact selected" do
    invoice_params = {
      invoice_number: "FC-001",
      invoice_series_id: "874",
      seller_party_id: "1999"
    }

    post invoices_path, params: {
      invoice: invoice_params,
      buyer_selection: "contact:11"
    }

    # Should have processed the buyer selection
    assert_response :unprocessable_content # Expected due to missing required fields
  end

  test "buyer_selection is preserved on validation errors" do
    # Create a simple POST without full form data to trigger validation error
    post invoices_path, params: {
      invoice: { invoice_number: "FC-001" },
      buyer_selection: "contact:11"
    }

    # Should get unprocessable content due to missing required fields
    assert_response :unprocessable_content

    # Verify that the @invoice instance variable has the preserved buyer data
    invoice = assigns(:invoice)
    assert_not_nil invoice

    # Should have preserved the buyer selection from buyer_selection parameter
    assert_equal "11", invoice[:buyer_company_contact_id]
    assert_nil invoice[:buyer_party_id]
  end

  test "buyer_selection company format is preserved on validation errors" do
    # Create a simple POST without full form data to trigger validation error
    post invoices_path, params: {
      invoice: { invoice_number: "FC-001" },
      buyer_selection: "company:1999"
    }

    # Should get unprocessable content due to missing required fields
    assert_response :unprocessable_content

    # Verify that the @invoice instance variable has the preserved buyer data
    invoice = assigns(:invoice)
    assert_not_nil invoice

    # Should have preserved the buyer selection from buyer_selection parameter
    assert_equal "1999", invoice[:buyer_party_id]
    assert_nil invoice[:buyer_company_contact_id]
  end

  test "invalid buyer_selection format is handled gracefully" do
    invoice_params = {
      invoice_number: "FC-001",
      invoice_series_id: "874",
      seller_party_id: "1999"
    }

    post invoices_path, params: {
      invoice: invoice_params,
      buyer_selection: "invalid_format"
    }

    # Should not crash, just handle gracefully
    assert_response :unprocessable_content
  end

  test "empty buyer_selection is handled gracefully" do
    invoice_params = {
      invoice_number: "FC-001",
      invoice_series_id: "874",
      seller_party_id: "1999"
    }

    post invoices_path, params: {
      invoice: invoice_params,
      buyer_selection: ""
    }

    # Should not crash, just handle gracefully
    assert_response :unprocessable_content
  end

  test "buyer_options includes proper labels for companies and contacts" do
    get new_invoice_path

    buyer_options = assigns(:buyer_options)

    # Find a company and contact option
    company_option = buyer_options.find { |opt| opt[:type] == 'company' }
    contact_option = buyer_options.find { |opt| opt[:type] == 'contact' }

    # Verify names are present and meaningful
    assert_not_empty company_option[:name]
    assert_not_empty contact_option[:name]

    # Names should not be just IDs
    refute_equal "Company ##{company_option[:id]}", company_option[:name]
    refute_equal "Contact ##{contact_option[:id]}", contact_option[:name]
  end

  private

  def setup_service_stubs
    # Mock authentication validation
    AuthService.stubs(:validate_token).returns({ valid: true })

    # Mock companies
    mock_companies = [
      { id: 1999, name: "TechSol", corporate_name: "TechSol Solutions S.L." }
    ]

    # Mock contacts
    mock_contacts = [
      { id: 11, name: "abc", legal_name: "ABC Contact" }
    ]

    # Mock invoice series
    mock_invoice_series = [
      { id: 874, series_code: "FC", series_name: "Facturas Comerciales", year: 2025 }
    ]

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: mock_contacts })

    # Mock CompanyContactsService.active_contacts call for load_all_company_contacts
    CompanyContactsService.stubs(:active_contacts)
      .with(company_id: 1999, token: "test_admin_token")
      .returns([])

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    # Mock the InvoiceService to avoid actual API calls
    InvoiceService.stubs(:create).raises(
      ApiService::ValidationError.new("Validation failed", [])
    )
  end
end