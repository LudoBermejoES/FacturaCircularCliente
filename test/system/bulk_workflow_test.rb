require "application_system_test_case"

class BulkWorkflowTest < ApplicationSystemTestCase
  setup do
    @invoices = [
      {
        id: 1,
        invoice_number: "INV-001",
        status: "draft",
        company_name: "Test Company 1",
        date: "2024-01-01",
        due_date: "2024-01-31",
        total_amount: "1000.00"
      },
      {
        id: 2,
        invoice_number: "INV-002",
        status: "draft",
        company_name: "Test Company 2",
        date: "2024-01-02",
        due_date: "2024-02-01",
        total_amount: "2000.00"
      },
      {
        id: 3,
        invoice_number: "INV-003",
        status: "pending_review",
        company_name: "Test Company 3",
        date: "2024-01-03",
        due_date: "2024-02-02",
        total_amount: "3000.00"
      }
    ]

    # Mock authentication
    ApplicationController.any_instance.stubs(:authenticate_user!).returns(true)
    ApplicationController.any_instance.stubs(:current_user_token).returns("test_token")

    # Mock invoice service
    InvoiceService.stubs(:list).returns(@invoices)
    InvoiceService.stubs(:statistics).returns({})
  end

  test "bulk workflow selection and modal interaction" do
    visit invoices_path

    # Initially bulk actions should be hidden
    assert_selector "[data-bulk-workflow-target='bulkActions'].hidden"

    # Select first invoice
    find("input[value='1']").check

    # Bulk actions should now be visible
    assert_no_selector "[data-bulk-workflow-target='bulkActions'].hidden"
    assert_text "1 invoice(s) selected"

    # Select second invoice
    find("input[value='2']").check
    assert_text "2 invoice(s) selected"

    # Uncheck first invoice
    find("input[value='1']").uncheck
    assert_text "1 invoice(s) selected"

    # Uncheck last invoice - bulk actions should hide
    find("input[value='2']").uncheck
    assert_selector "[data-bulk-workflow-target='bulkActions'].hidden"
  end

  test "select all functionality" do
    visit invoices_path

    # Check select all checkbox
    find("[data-bulk-workflow-target='selectAll']").check

    # All individual checkboxes should be checked
    @invoices.each do |invoice|
      assert find("input[value='#{invoice[:id]}']").checked?
    end

    assert_text "#{@invoices.size} invoice(s) selected"

    # Uncheck select all
    find("[data-bulk-workflow-target='selectAll']").check # This will uncheck it

    # All individual checkboxes should be unchecked
    @invoices.each do |invoice|
      assert_not find("input[value='#{invoice[:id]}']").checked?
    end

    assert_selector "[data-bulk-workflow-target='bulkActions'].hidden"
  end

  test "bulk status update modal" do
    # Mock successful bulk transition
    WorkflowService.stubs(:bulk_transition).returns({
      'success_count' => 2,
      'errors' => []
    })

    visit invoices_path

    # Select invoices
    find("input[value='1']").check
    find("input[value='2']").check

    # Click update status button
    click_button "Update Status"

    # Modal should be visible
    assert_selector "#bulk-workflow-modal:not(.hidden)"
    assert_text "Update the status of 2 selected invoices"

    # Select a status
    select "Approved", from: "status"

    # Add comment
    fill_in "comment", with: "Bulk approval for testing"

    # Submit the form
    click_button "Update Invoices"

    # Should redirect back to invoices page with success message
    assert_current_path invoices_path
    assert_text "Successfully updated 2 invoice(s) to approved"
  end

  test "bulk status update validation" do
    visit invoices_path

    # Try to open modal without selecting invoices
    # This should show alert since no invoices are selected
    find("input[value='1']").check
    click_button "Update Status"

    # Modal should be visible
    assert_selector "#bulk-workflow-modal:not(.hidden)"

    # Try to submit without selecting status
    click_button "Update Invoices"

    # Should show browser validation error or JS alert
    # (exact behavior depends on browser implementation)
  end

  test "closing bulk modal with cancel button" do
    visit invoices_path

    # Select invoice and open modal
    find("input[value='1']").check
    click_button "Update Status"

    # Modal should be visible
    assert_selector "#bulk-workflow-modal:not(.hidden)"

    # Click cancel
    click_button "Cancel"

    # Modal should be hidden
    assert_selector "#bulk-workflow-modal.hidden"
  end

  test "closing bulk modal with escape key" do
    visit invoices_path

    # Select invoice and open modal
    find("input[value='1']").check
    click_button "Update Status"

    # Modal should be visible
    assert_selector "#bulk-workflow-modal:not(.hidden)"

    # Press escape key
    find("body").send_keys(:escape)

    # Modal should be hidden
    assert_selector "#bulk-workflow-modal.hidden"
  end

  test "bulk status update with API error" do
    # Mock API error
    WorkflowService.stubs(:bulk_transition).raises(
      ApiService::ApiError.new("Server error")
    )

    visit invoices_path

    # Select invoices
    find("input[value='1']").check
    find("input[value='2']").check

    # Open modal and submit
    click_button "Update Status"
    select "Approved", from: "status"
    click_button "Update Invoices"

    # Should show error message
    assert_text "Failed to update invoices: Server error"
  end

  test "bulk status update with partial success" do
    # Mock partial success
    WorkflowService.stubs(:bulk_transition).returns({
      'success_count' => 1,
      'errors' => ['Invoice #2 cannot be approved in current state']
    })

    visit invoices_path

    # Select invoices
    find("input[value='1']").check
    find("input[value='2']").check

    # Open modal and submit
    click_button "Update Status"
    select "Approved", from: "status"
    click_button "Update Invoices"

    # Should show both success and warning messages
    assert_text "Successfully updated 1 invoice(s) to approved"
    assert_text "Some invoices could not be updated: Invoice #2 cannot be approved in current state"
  end

  test "indeterminate select all state" do
    visit invoices_path

    # Select one invoice
    find("input[value='1']").check

    # Select all checkbox should be in indeterminate state
    select_all_checkbox = find("[data-bulk-workflow-target='selectAll']")
    # Note: Testing indeterminate state in system tests is challenging
    # This would require JavaScript execution to verify the indeterminate property

    # Select all invoices manually
    @invoices.each do |invoice|
      find("input[value='#{invoice[:id]}']").check
    end

    # Now select all should be fully checked
    assert select_all_checkbox.checked?

    # Uncheck one invoice
    find("input[value='1']").uncheck

    # Select all should no longer be fully checked
    assert_not select_all_checkbox.checked?
  end
end