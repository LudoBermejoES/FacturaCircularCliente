require "test_helper"

class InvoiceNumberingServiceTest < ActiveSupport::TestCase
  def setup
    @token = "test_token"
    @year = 2025
    @series_type = "commercial"
  end

  test "next_available returns available numbers when API call succeeds" do
    mock_response = {
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
    }

    InvoiceNumberingService.stubs(:get)
      .with('/invoice_numbering/next_available', token: @token, params: { year: @year, series_type: @series_type })
      .returns(mock_response)

    result = InvoiceNumberingService.next_available(
      token: @token,
      year: @year,
      series_type: @series_type
    )

    expected_attributes = {
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

    assert_equal expected_attributes, result
  end

  test "next_available returns empty hash when API response is malformed" do
    mock_response = {
      data: {
        type: "next_available_numbers"
        # Missing attributes
      }
    }

    InvoiceNumberingService.stubs(:get)
      .with('/invoice_numbering/next_available', token: @token, params: { year: @year, series_type: @series_type })
      .returns(mock_response)

    result = InvoiceNumberingService.next_available(
      token: @token,
      year: @year,
      series_type: @series_type
    )

    assert_equal({}, result)
  end

  test "next_available returns empty hash when API response is nil" do
    InvoiceNumberingService.stubs(:get)
      .with('/invoice_numbering/next_available', token: @token, params: { year: @year, series_type: @series_type })
      .returns(nil)

    result = InvoiceNumberingService.next_available(
      token: @token,
      year: @year,
      series_type: @series_type
    )

    assert_equal({}, result)
  end

  test "next_available uses correct default parameters" do
    InvoiceNumberingService.expects(:get)
      .with('/invoice_numbering/next_available', token: @token, params: { year: @year, series_type: @series_type })
      .returns({ data: { attributes: {} } })

    InvoiceNumberingService.next_available(
      token: @token,
      year: @year,
      series_type: @series_type
    )
  end

  test "next_available handles API errors gracefully" do
    InvoiceNumberingService.stubs(:get)
      .with('/invoice_numbering/next_available', token: @token, params: { year: @year, series_type: @series_type })
      .raises(ApiService::ApiError, "API Error")

    assert_raises(ApiService::ApiError) do
      InvoiceNumberingService.next_available(
        token: @token,
        year: @year,
        series_type: @series_type
      )
    end
  end
end