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
end