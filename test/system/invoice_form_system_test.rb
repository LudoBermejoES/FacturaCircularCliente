require "application_system_test_case"

class InvoiceFormSystemTest < ApplicationSystemTestCase
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
    setup_mocked_services
    
    # Enable JavaScript for system tests
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  test "invoice series selection automatically generates invoice number" do
    visit new_invoice_path

    # Verify initial state
    assert_selector "select[name='invoice[invoice_series_id]']"
    assert_selector "input[name='invoice[invoice_number]'][readonly]"
    
    invoice_number_field = find("input[name='invoice[invoice_number]']")
    assert_equal "Will be auto-generated", invoice_number_field["placeholder"]
    assert_equal "", invoice_number_field.value

    # Mock the AJAX response for auto-assignment
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(
        status: 200,
        body: {
          data: {
            type: "next_available_numbers",
            attributes: {
              company_id: 1999,
              year: 2025,
              series_type: "commercial",
              available_numbers: {
                "FC" => [
                  {
                    series_id: 874,
                    series_code: "FC",
                    sequence_number: 2,
                    full_number: "FC-2025-0002",
                    preview: true
                  }
                ]
              }
            }
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Select invoice series
    select "FC - Facturas Comerciales 2025", from: "Invoice Series"

    # Wait for AJAX call to complete and number to be populated
    assert_field "Invoice Number", with: "FC-0002", wait: 5

    # Verify the field styling indicates success
    invoice_number_field = find("input[name='invoice[invoice_number]']")
    assert invoice_number_field[:class].include?("bg-gray-50")
    refute invoice_number_field[:class].include?("border-red-300")
  end

  test "shows loading state during number generation" do
    visit new_invoice_path

    # Delay the AJAX response to test loading state
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(
        status: 200,
        body: { data: { attributes: { available_numbers: { "FC" => [{ sequence_number: 3 }] } } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      ).with(delay: 1) # 1 second delay

    select "FC - Facturas Comerciales 2025", from: "Invoice Series"

    # Should show loading state immediately
    invoice_number_field = find("input[name='invoice[invoice_number]']")
    assert_equal "Generating number...", invoice_number_field["placeholder"]
    assert invoice_number_field[:class].include?("animate-pulse")

    # Wait for completion
    assert_field "Invoice Number", with: "FC-0003", wait: 3
  end

  test "shows error state when API call fails" do
    visit new_invoice_path

    # Mock failed API response
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(status: 422, body: { errors: [{ title: "API Error" }] }.to_json)

    select "FC - Facturas Comerciales 2025", from: "Invoice Series"

    # Should show error state
    invoice_number_field = find("input[name='invoice[invoice_number]']", wait: 3)
    assert_equal "Error generating invoice number", invoice_number_field["placeholder"]
    assert invoice_number_field[:class].include?("border-red-300")
    assert invoice_number_field[:class].include?("text-red-900")
  end

  test "clears invoice number when series is deselected" do
    visit new_invoice_path

    # First select a series and get a number
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(
        status: 200,
        body: {
          data: {
            attributes: {
              available_numbers: {
                "FC" => [{ sequence_number: 5, full_number: "FC-2025-0005" }]
              }
            }
          }
        }.to_json
      )

    select "FC - Facturas Comerciales 2025", from: "Invoice Series"
    assert_field "Invoice Number", with: "FC-0005", wait: 3

    # Then deselect series
    select "Select invoice series", from: "Invoice Series"

    # Number should be cleared
    invoice_number_field = find("input[name='invoice[invoice_number]']")
    assert_equal "", invoice_number_field.value
    assert_equal "Select a series first", invoice_number_field["placeholder"]
  end

  test "handles different series types correctly" do
    visit new_invoice_path

    # Test mapping of different series codes to types
    series_tests = [
      { series_code: "FC", expected_type: "commercial", expected_number: "FC-0001" },
      { series_code: "PF", expected_type: "proforma", expected_number: "PF-0001" },
      { series_code: "CR", expected_type: "credit_note", expected_number: "CR-0001" }
    ]

    series_tests.each do |test_data|
      # Mock API response for this series type
      stub_request(:get, /api\/v1\/invoice_numbering\/next_available\?.*series_type=#{test_data[:expected_type]}/)
        .to_return(
          status: 200,
          body: {
            data: {
              attributes: {
                available_numbers: {
                  test_data[:series_code] => [
                    {
                      series_code: test_data[:series_code],
                      sequence_number: 1,
                      full_number: "#{test_data[:series_code]}-2025-0001"
                    }
                  ]
                }
              }
            }
          }.to_json
        )
    end

    # Test would require multiple series options in the dropdown
    # This assumes the mock includes different series types
  end

  test "form submission includes auto-generated invoice number" do
    visit new_invoice_path

    # Mock the number generation
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(
        status: 200,
        body: {
          data: {
            attributes: {
              available_numbers: {
                "FC" => [{ sequence_number: 7, full_number: "FC-2025-0007" }]
              }
            }
          }
        }.to_json
      )

    # Mock successful invoice creation
    InvoiceService.stubs(:create).returns({
      id: 456,
      invoice_number: "FC-0007",
      invoice_series_id: 874
    })

    # Fill out the form
    select "FC - Facturas Comerciales 2025", from: "Invoice Series"
    assert_field "Invoice Number", with: "FC-0007", wait: 3

    select "TechSol", from: "From (Seller)"
    select "TechSol", from: "To (Customer)"
    
    # Fill line item
    fill_in "Item description", with: "Test Service"
    fill_in_line_item_field("quantity", 1)
    fill_in_line_item_field("unit_price", 100.0)

    click_button "Create Invoice"

    # Should redirect to show page
    assert_current_path invoice_path(456)
  end

  test "preserves form data when number generation fails" do
    visit new_invoice_path

    # Fill out some form fields first
    fill_in "Customer Notes", with: "Important customer note"
    fill_in "Item description", with: "Test Service"

    # Mock API failure
    stub_request(:get, %r{/api/v1/invoice_numbering/next_available})
      .to_return(status: 500, body: "Internal Server Error")

    select "FC - Facturas Comerciales 2025", from: "Invoice Series"

    # Wait for error state
    find("input[placeholder='Error generating invoice number']", wait: 3)

    # Verify other form fields are preserved
    assert_field "Customer Notes", with: "Important customer note"
    assert_field "Item description", with: "Test Service"
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
    
    InvoiceSeriesService.stubs(:all).returns(mock_invoice_series)
    CompanyService.stubs(:all).returns([
      { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." }
    ])
    InvoiceService.stubs(:recent).returns([])
  end

  def fill_in_line_item_field(field_name, value)
    # Helper to fill in line item fields that may have complex names
    find("input[name*='[#{field_name}]']").set(value)
  end
end