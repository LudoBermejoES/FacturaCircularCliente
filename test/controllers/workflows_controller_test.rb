require "test_helper"

class WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_token = "test_token_123"
    @invoice = {
      id: 1,
      invoice_number: "INV-001",
      status: "draft"
    }

    # Mock authentication
    ApplicationController.any_instance.stubs(:authenticate_user!).returns(true)
    ApplicationController.any_instance.stubs(:current_user_token).returns(@user_token)
  end

  test "should handle bulk transition with valid parameters" do
    invoice_ids = [1, 2, 3]
    status = "approved"
    comment = "Bulk approval"

    expected_result = {
      'success_count' => 3,
      'errors' => []
    }

    WorkflowService.stubs(:bulk_transition).returns(expected_result)

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status,
      comment: comment
    }

    assert_redirected_to invoices_path
    assert_equal "Successfully updated 3 invoice(s) to approved", flash[:success]
  end

  test "should handle bulk transition with partial success" do
    invoice_ids = [1, 2, 3]
    status = "approved"

    result_with_errors = {
      'success_count' => 2,
      'errors' => ['Invoice #3 cannot be approved']
    }

    WorkflowService.stubs(:bulk_transition).returns(result_with_errors)

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status
    }

    assert_redirected_to invoices_path
    assert_equal "Successfully updated 2 invoice(s) to approved", flash[:success]
    assert_equal "Some invoices could not be updated: Invoice #3 cannot be approved", flash[:warning]
  end

  test "should handle bulk transition validation errors" do
    invoice_ids = [1, 2]
    status = "invalid_status"

    WorkflowService.stubs(:bulk_transition).raises(
      ApiService::ValidationError.new("Invalid status", ["Status is not valid"])
    )

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status
    }

    assert_redirected_to invoices_path
    assert_equal "Validation error: Status is not valid", flash[:error]
  end

  test "should handle bulk transition API errors" do
    invoice_ids = [1, 2]
    status = "approved"

    WorkflowService.stubs(:bulk_transition).raises(
      ApiService::ApiError.new("Server error")
    )

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status
    }

    assert_redirected_to invoices_path
    assert_equal "Failed to update invoices: Server error", flash[:error]
  end

  test "should require invoice_ids parameter" do
    post bulk_invoice_transition_path, params: {
      status: "approved"
    }

    assert_redirected_to invoices_path
    assert_equal "Please select invoices and specify a status", flash[:alert]
  end

  test "should require status parameter" do
    post bulk_invoice_transition_path, params: {
      invoice_ids: [1, 2]
    }

    assert_redirected_to invoices_path
    assert_equal "Please select invoices and specify a status", flash[:alert]
  end

  test "should reject empty invoice_ids array" do
    post bulk_invoice_transition_path, params: {
      invoice_ids: ["", "", ""],
      status: "approved"
    }

    assert_redirected_to invoices_path
    assert_equal "Please select at least one invoice", flash[:alert]
  end

  test "should filter out blank invoice_ids" do
    invoice_ids = ["1", "", "2", "", "3"]
    expected_filtered_ids = [1, 2, 3]

    expected_result = {
      'success_count' => 3,
      'errors' => []
    }

    WorkflowService.expects(:bulk_transition).with(
      expected_filtered_ids,
      status: "approved",
      comment: nil,
      token: @user_token
    ).returns(expected_result)

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: "approved"
    }

    assert_redirected_to invoices_path
    assert_equal "Successfully updated 3 invoice(s) to approved", flash[:success]
  end

  test "should handle bulk transition with comment" do
    invoice_ids = [1, 2]
    status = "approved"
    comment = "Bulk approval with comment"

    expected_result = {
      'success_count' => 2,
      'errors' => []
    }

    WorkflowService.expects(:bulk_transition).with(
      invoice_ids,
      status: status,
      comment: comment,
      token: @user_token
    ).returns(expected_result)

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status,
      comment: comment
    }

    assert_redirected_to invoices_path
    assert_equal "Successfully updated 2 invoice(s) to approved", flash[:success]
  end

  test "should handle bulk transition without explicit success count" do
    invoice_ids = [1, 2, 3]
    status = "sent"

    # API returns result without success_count field
    result_without_count = {
      'errors' => []
    }

    WorkflowService.stubs(:bulk_transition).returns(result_without_count)

    post bulk_invoice_transition_path, params: {
      invoice_ids: invoice_ids,
      status: status
    }

    assert_redirected_to invoices_path
    # Should default to the number of requested invoices
    assert_equal "Successfully updated 3 invoice(s) to sent", flash[:success]
  end

  test "should show workflow page with available transitions" do
    invoice_id = @invoice[:id]
    # Mock API response format
    mock_api_response = {
      current_state: { name: "draft", display_name: "Draft" },
      available_transitions: [
        {
          transition: {
            description: "Move to approved status",
            requires_comment: false
          },
          to_state: {
            code: "approved",
            name: "Approved"
          },
          can_transition: true,
          reason: nil
        },
        {
          transition: {
            description: "Send the invoice",
            requires_comment: true
          },
          to_state: {
            code: "sent",
            name: "Sent"
          },
          can_transition: true,
          reason: nil
        }
      ]
    }

    mock_history = [
      {
        from_status: "draft",
        to_status: "review",
        comment: "Initial submission",
        user_name: "Admin User",
        created_at: "2025-01-01T10:00:00Z"
      }
    ]

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:available_transitions).returns(mock_api_response)
    WorkflowService.stubs(:history).returns(mock_history)

    get invoice_workflow_path(invoice_id)

    assert_response :success
    assert_not_nil assigns(:invoice)
    assert_not_nil assigns(:available_transitions)
    assert_not_nil assigns(:history)

    # Check that the transitions were properly transformed
    assert_equal 2, assigns(:available_transitions).length
    assert_equal "approved", assigns(:available_transitions).first[:to_status]
    assert_equal "Approved", assigns(:available_transitions).first[:to_status_name]
    assert_equal "Move to approved status", assigns(:available_transitions).first[:description]
    assert_equal false, assigns(:available_transitions).first[:requires_comment]
  end

  test "should handle workflow page with empty transitions" do
    invoice_id = @invoice[:id]

    # Mock API response with empty transitions
    mock_api_response = {
      current_state: { name: "draft", display_name: "Draft" },
      available_transitions: []
    }

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:available_transitions).returns(mock_api_response)
    WorkflowService.stubs(:history).returns([])

    get invoice_workflow_path(invoice_id)

    assert_response :success
    assert_equal [], assigns(:available_transitions)
    assert_equal [], assigns(:history)
  end

  test "should handle workflow page API errors gracefully" do
    invoice_id = @invoice[:id]  # Use the same ID from setup

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:available_transitions).raises(ApiService::ApiError.new("Service unavailable"))
    WorkflowService.stubs(:history).returns([])

    get invoice_workflow_path(invoice_id)

    assert_redirected_to invoice_path(invoice_id)
    assert_not_nil flash[:alert]
  end

  test "should transition invoice status successfully" do
    mock_result = { status: "approved" }
    updated_invoice = @invoice.merge(status: "approved")

    # Mock all the service calls in sequence
    InvoiceService.stubs(:find).returns(@invoice, updated_invoice)
    WorkflowService.stubs(:transition).returns(mock_result)
    WorkflowService.stubs(:history).returns([])
    WorkflowService.stubs(:available_transitions).returns({ available_transitions: [] })

    post transition_invoice_workflow_path(@invoice[:id]),
         params: { status: "approved", comment: "Test approval" },
         as: :turbo_stream

    assert_response :success
    assert_template :transition
  end

  test "should handle transition validation errors with new error format" do
    errors = [
      { status: "422", title: "Unprocessable content", detail: "Status is required", code: "MISSING_STATUS" }
    ]

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:transition).raises(ApiService::ValidationError.new("Validation failed", errors))

    post transition_invoice_workflow_path(@invoice[:id]),
         params: { status: "invalid_status", comment: "" },
         as: :turbo_stream

    assert_response :success
    assert_match "workflow_errors", response.body
    assert_match "Status is required", response.body
  end

  test "should handle transition API errors" do
    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:transition).raises(ApiService::ApiError.new("Server error"))

    post transition_invoice_workflow_path(@invoice[:id]),
         params: { status: "approved", comment: "" }

    assert_redirected_to invoice_path(@invoice[:id])
  end

  test "should send correct status parameter format to API" do
    mock_result = { status: "approved" }
    updated_invoice = @invoice.merge(status: "approved")

    # Expect the API call with the correct format
    WorkflowService.expects(:transition).with(
      @invoice[:id],
      status: "approved",
      comment: "Test comment",
      token: @user_token
    ).returns(mock_result)

    # Mock the service calls in proper sequence
    InvoiceService.stubs(:find).returns(@invoice, updated_invoice)
    WorkflowService.stubs(:history).returns([])
    WorkflowService.stubs(:available_transitions).returns({ available_transitions: [] })

    post transition_invoice_workflow_path(@invoice[:id]),
         params: { status: "approved", comment: "Test comment" },
         as: :turbo_stream

    assert_response :success
  end

  test "should handle HTML format transition requests" do
    mock_result = { status: "approved" }

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:transition).returns(mock_result)

    post transition_invoice_workflow_path(@invoice[:id]),
         params: { status: "approved", comment: "Test approval" }

    assert_redirected_to invoice_path(@invoice[:id])
    assert_equal "Invoice status updated to approved", flash[:notice]
  end

  test "should transform API response correctly for both symbol and string keys" do
    # Test with symbol keys (primary format)
    mock_api_response_symbols = {
      available_transitions: [
        {
          transition: { description: "Approve", requires_comment: false },
          to_state: { code: "approved", name: "Approved" }
        }
      ]
    }

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:available_transitions).returns(mock_api_response_symbols)
    WorkflowService.stubs(:history).returns([])

    get invoice_workflow_path(@invoice[:id])

    assert_response :success
    transitions = assigns(:available_transitions)
    assert_equal 1, transitions.length
    assert_equal "approved", transitions.first[:to_status]
    assert_equal "Approved", transitions.first[:to_status_name]
  end

  test "should transform API response correctly with string keys" do
    # Test with string keys (fallback format) - need to symbolize the root key
    mock_api_response_strings = {
      available_transitions: [
        {
          'transition' => { 'description' => "Approve", 'requires_comment' => false },
          'to_state' => { 'code' => "approved", 'name' => "Approved" }
        }
      ]
    }

    InvoiceService.stubs(:find).returns(@invoice)
    WorkflowService.stubs(:available_transitions).returns(mock_api_response_strings)
    WorkflowService.stubs(:history).returns([])

    get invoice_workflow_path(@invoice[:id])

    assert_response :success
    transitions = assigns(:available_transitions)
    assert_equal 1, transitions.length
    assert_equal "approved", transitions.first[:to_status]
    assert_equal "Approved", transitions.first[:to_status_name]
  end
end