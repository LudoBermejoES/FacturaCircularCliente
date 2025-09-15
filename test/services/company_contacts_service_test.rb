require "test_helper"

class CompanyContactsServiceTest < ActiveSupport::TestCase
  setup do
    @token = "test_token"
    @company_id = 1
    @contact_id = 1
    
    @mock_api_response = {
      data: [
        {
          id: "1",
          type: "company_contacts",
          attributes: {
            name: "Acme Corp",
            legal_name: "Acme Corporation S.L.",
            tax_id: "B12345678",
            email: "info@acmecorp.com",
            phone: "+34 911 555 000",
            website: "https://www.acmecorp.com",
            is_active: true
          }
        }
      ],
      meta: { total: 1, page: 1, pages: 1 }
    }
    
    @mock_single_response = {
      data: {
        id: "1",
        type: "company_contacts",
        attributes: {
          name: "Acme Corp",
          legal_name: "Acme Corporation S.L.",
          tax_id: "B12345678",
          email: "info@acmecorp.com",
          phone: "+34 911 555 000",
          website: "https://www.acmecorp.com",
          is_active: true
        }
      }
    }
    
    @contact_params = {
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

  test "all should transform JSON API response to expected format" do
    CompanyContactsService.stubs(:get).returns(@mock_api_response)
    
    result = CompanyContactsService.all(company_id: @company_id, token: @token)
    
    assert_equal 1, result[:contacts].size
    contact = result[:contacts].first
    
    assert_equal 1, contact[:id]
    assert_equal "Acme Corp", contact[:name]
    assert_equal "Acme Corporation S.L.", contact[:legal_name]
    assert_equal "B12345678", contact[:tax_id]
    assert_equal "info@acmecorp.com", contact[:email]
    assert_equal "+34 911 555 000", contact[:phone]
    assert_equal "https://www.acmecorp.com", contact[:website]
    assert_equal true, contact[:is_active]
    
    assert_equal({ total: 1, page: 1, pages: 1 }, result[:meta])
  end

  test "all should handle empty response" do
    empty_response = { data: [], meta: { total: 0 } }
    CompanyContactsService.stubs(:get).returns(empty_response)
    
    result = CompanyContactsService.all(company_id: @company_id, token: @token)
    
    assert_equal 0, result[:contacts].size
    assert_equal({ total: 0 }, result[:meta])
  end

  test "find should transform single contact response" do
    CompanyContactsService.stubs(:get).returns(@mock_single_response)
    
    result = CompanyContactsService.find(company_id: @company_id, id: @contact_id, token: @token)
    
    assert_equal 1, result[:id]
    assert_equal "Acme Corp", result[:name]
    assert_equal "Acme Corporation S.L.", result[:legal_name]
    assert_equal "B12345678", result[:tax_id]
    assert_equal "info@acmecorp.com", result[:email]
    assert_equal "+34 911 555 000", result[:phone]
    assert_equal "https://www.acmecorp.com", result[:website]
    assert_equal true, result[:is_active]
  end

  test "find should handle missing data" do
    empty_response = {}
    CompanyContactsService.stubs(:get).returns(empty_response)
    
    result = CompanyContactsService.find(company_id: @company_id, id: @contact_id, token: @token)
    
    assert_equal empty_response, result
  end

  test "create should format request correctly" do
    expected_request_body = {
      data: {
        type: 'company_contacts',
        attributes: {
          name: "New Contact Corp",
          legal_name: "New Contact Corporation Ltd",
          tax_id: "D99999999",
          email: "info@newcontact.com",
          phone: "+34 933 777 888",
          website: "https://www.newcontact.com",
          is_active: true,
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
      }
    }
    
    CompanyContactsService.expects(:post).with(
      "/companies/#{@company_id}/contacts",
      token: @token,
      body: expected_request_body
    ).returns({ data: { id: 3 } })
    
    result = CompanyContactsService.create(
      company_id: @company_id,
      params: @contact_params,
      token: @token
    )
    
    assert_equal({ data: { id: 3 } }, result)
  end

  test "create should handle addresses properly" do
    params_with_multiple_addresses = @contact_params.merge(
      addresses: [
        {
          address_type: "billing",
          street_address: "Billing Street 123",
          city: "Madrid",
          postal_code: "28013",
          state_province: "Madrid",
          country_code: "ESP",
          is_default: true
        },
        {
          address_type: "shipping",
          street_address: "Shipping Avenue 456",
          city: "Barcelona",
          postal_code: "08001",
          state_province: "Barcelona",
          country_code: "ESP",
          is_default: false
        }
      ]
    )
    
    CompanyContactsService.expects(:post).with do |endpoint, options|
      body = options[:body]
      addresses = body[:data][:attributes][:addresses]
      
      addresses.size == 2 &&
      addresses[0][:address_type] == "billing" &&
      addresses[0][:is_default] == true &&
      addresses[1][:address_type] == "shipping" &&
      addresses[1][:is_default] == false
    end.returns({ data: { id: 3 } })
    
    CompanyContactsService.create(
      company_id: @company_id,
      params: params_with_multiple_addresses,
      token: @token
    )
  end

  test "create should filter out empty addresses" do
    params_with_empty_address = @contact_params.merge(
      addresses: [
        {
          address_type: "billing",
          street_address: "Valid Address 123",
          city: "Madrid",
          postal_code: "28013",
          state_province: "Madrid",
          country_code: "ESP",
          is_default: true
        },
        {
          address_type: "shipping",
          street_address: "", # Empty street address should be filtered out
          city: "",
          postal_code: "",
          state_province: "",
          country_code: "ESP",
          is_default: false
        }
      ]
    )
    
    CompanyContactsService.expects(:post).with do |endpoint, options|
      body = options[:body]
      addresses = body[:data][:attributes][:addresses]
      
      addresses.size == 1 && # Only one address should remain
      addresses[0][:address_type] == "billing"
    end.returns({ data: { id: 3 } })
    
    CompanyContactsService.create(
      company_id: @company_id,
      params: params_with_empty_address,
      token: @token
    )
  end

  test "create should handle boolean is_default values" do
    params_with_boolean = @contact_params.dup
    params_with_boolean[:addresses][0][:is_default] = "true" # String value
    
    CompanyContactsService.expects(:post).with do |endpoint, options|
      body = options[:body]
      addresses = body[:data][:attributes][:addresses]
      
      addresses[0][:is_default] == true # Should convert to boolean
    end.returns({ data: { id: 3 } })
    
    CompanyContactsService.create(
      company_id: @company_id,
      params: params_with_boolean,
      token: @token
    )
  end

  test "update should format request correctly" do
    update_params = {
      name: "Updated Name",
      email: "updated@example.com"
    }
    
    expected_request_body = {
      data: {
        type: 'company_contacts',
        attributes: {
          name: "Updated Name",
          email: "updated@example.com",
          is_active: true
        }
      }
    }
    
    CompanyContactsService.expects(:put).with(
      "/companies/#{@company_id}/contacts/#{@contact_id}",
      token: @token,
      body: expected_request_body
    ).returns({ data: { id: @contact_id } })
    
    result = CompanyContactsService.update(
      company_id: @company_id,
      id: @contact_id,
      params: update_params,
      token: @token
    )
    
    assert_equal({ data: { id: @contact_id } }, result)
  end

  test "destroy should call correct endpoint" do
    CompanyContactsService.expects(:delete).with(
      "/companies/#{@company_id}/contacts/#{@contact_id}",
      token: @token
    ).returns(true)
    
    result = CompanyContactsService.destroy(
      company_id: @company_id,
      id: @contact_id,
      token: @token
    )
    
    assert_equal true, result
  end

  test "activate should call correct endpoint" do
    CompanyContactsService.expects(:post).with(
      "/companies/#{@company_id}/contacts/#{@contact_id}/activate",
      token: @token,
      body: {}
    ).returns({ data: { id: @contact_id } })
    
    result = CompanyContactsService.activate(
      company_id: @company_id,
      id: @contact_id,
      token: @token
    )
    
    assert_equal({ data: { id: @contact_id } }, result)
  end

  test "deactivate should call correct endpoint" do
    CompanyContactsService.expects(:post).with(
      "/companies/#{@company_id}/contacts/#{@contact_id}/deactivate",
      token: @token,
      body: {}
    ).returns({ data: { id: @contact_id } })
    
    result = CompanyContactsService.deactivate(
      company_id: @company_id,
      id: @contact_id,
      token: @token
    )
    
    assert_equal({ data: { id: @contact_id } }, result)
  end

  test "active_contacts should transform response for invoice usage" do
    CompanyContactsService.stubs(:get).returns(@mock_api_response)
    
    result = CompanyContactsService.active_contacts(company_id: @company_id, token: @token)
    
    assert_equal 1, result.size
    contact = result.first
    
    assert_equal 1, contact[:id]
    assert_equal "Acme Corp", contact[:name]
    assert_equal "info@acmecorp.com", contact[:email]
    assert_equal "+34 911 555 000", contact[:phone]
    assert_equal "Acme Corp Acme Corporation S.L.", contact[:full_name]
  end

  test "all should pass correct parameters" do
    params = { page: 2, per_page: 10, search: "test" }
    
    CompanyContactsService.expects(:get).with(
      "/companies/#{@company_id}/contacts",
      token: @token,
      params: params
    ).returns(@mock_api_response)
    
    CompanyContactsService.all(
      company_id: @company_id,
      token: @token,
      params: params
    )
  end
end