require "test_helper"

class WorkflowServiceTest < ActiveSupport::TestCase
  setup do
    @user_token = "test_token_123"
    @invoice_id = "12"
  end

  test "transition sends correct JSON API format to backend" do
    expected_body = {
      data: {
        attributes: {
          status: "approved",
          comment: "Test comment"
        }
      }
    }

    # Mock the HTTP request to verify the body format
    ApiService.expects(:patch).with(
      "/invoices/#{@invoice_id}/status",
      body: expected_body,
      token: @user_token
    ).returns({ status: "approved" })

    result = WorkflowService.transition(
      @invoice_id,
      status: "approved",
      comment: "Test comment",
      token: @user_token
    )

    assert_equal({ status: "approved" }, result)
  end

  test "transition handles nil comment correctly" do
    expected_body = {
      data: {
        attributes: {
          status: "approved"
        }
      }
    }

    # Mock the HTTP request to verify comment is removed when nil
    ApiService.expects(:patch).with(
      "/invoices/#{@invoice_id}/status",
      body: expected_body,
      token: @user_token
    ).returns({ status: "approved" })

    WorkflowService.transition(
      @invoice_id,
      status: "approved",
      comment: nil,
      token: @user_token
    )
  end

  test "transition handles empty comment correctly" do
    expected_body = {
      data: {
        attributes: {
          status: "approved",
          comment: ""
        }
      }
    }

    # Mock the HTTP request to verify empty comment is preserved
    ApiService.expects(:patch).with(
      "/invoices/#{@invoice_id}/status",
      body: expected_body,
      token: @user_token
    ).returns({ status: "approved" })

    WorkflowService.transition(
      @invoice_id,
      status: "approved",
      comment: "",
      token: @user_token
    )
  end

  test "available_transitions calls correct endpoint" do
    mock_response = {
      available_transitions: [
        {
          transition: { description: "Approve", requires_comment: false },
          to_state: { code: "approved", name: "Approved" }
        }
      ]
    }

    ApiService.expects(:get).with(
      "/invoices/#{@invoice_id}/workflow/available_transitions",
      token: @user_token
    ).returns(mock_response)

    result = WorkflowService.available_transitions(@invoice_id, token: @user_token)

    assert_equal mock_response, result
  end

  test "history calls correct endpoint" do
    mock_history = [
      {
        from_status: "draft",
        to_status: "approved",
        comment: "Test",
        user_name: "Admin",
        created_at: "2025-01-01T10:00:00Z"
      }
    ]

    ApiService.expects(:get).with(
      '/workflow_history',
      token: @user_token,
      params: { invoice_id: @invoice_id }
    ).returns(mock_history)

    result = WorkflowService.history(
      token: @user_token,
      params: { invoice_id: @invoice_id }
    )

    assert_equal mock_history, result
  end

  test "bulk_transition sends correct format" do
    invoice_ids = [1, 2, 3]
    expected_body = {
      invoice_ids: invoice_ids,
      status: "approved",
      comment: "Bulk approval"
    }

    ApiService.expects(:post).with(
      "/invoices/bulk_transition",
      body: expected_body,
      token: @user_token
    ).returns({ success_count: 3, errors: [] })

    result = WorkflowService.bulk_transition(
      invoice_ids,
      status: "approved",
      comment: "Bulk approval",
      token: @user_token
    )

    assert_equal({ success_count: 3, errors: [] }, result)
  end
end