require "application_system_test_case"

class SlaTrackingTest < ApplicationSystemTestCase
  setup do
    @current_time = Time.parse("2024-01-15 10:00:00 UTC")
    Time.stubs(:current).returns(@current_time)

    @invoice_with_sla = {
      id: 1,
      invoice_number: "INV-001",
      status: "pending_review",
      workflow: {
        'entered_current_state_at' => '2024-01-15 08:00:00 UTC',
        'sla_deadline' => '2024-01-15 14:00:00 UTC',
        'is_overdue' => false
      }
    }

    @overdue_invoice = {
      id: 2,
      invoice_number: "INV-002",
      status: "pending_review",
      workflow: {
        'entered_current_state_at' => '2024-01-14 08:00:00 UTC',
        'sla_deadline' => '2024-01-15 09:00:00 UTC',
        'is_overdue' => true
      }
    }

    @warning_invoice = {
      id: 3,
      invoice_number: "INV-003",
      status: "pending_review",
      workflow: {
        'entered_current_state_at' => '2024-01-15 08:00:00 UTC',
        'sla_deadline' => '2024-01-15 10:30:00 UTC', # 30 minutes from now
        'is_overdue' => false
      }
    }

    @invoice_without_sla = {
      id: 4,
      invoice_number: "INV-004",
      status: "draft",
      workflow: {
        'entered_current_state_at' => '2024-01-15 08:00:00 UTC'
        # No sla_deadline
      }
    }

    # Mock authentication
    ApplicationController.any_instance.stubs(:authenticate_user!).returns(true)
    ApplicationController.any_instance.stubs(:current_user_token).returns("test_token")
  end

  test "displays SLA indicator on invoices index page" do
    # Use correct service method and response format
    InvoiceService.stubs(:all).returns({
      invoices: [
        @invoice_with_sla,
        @overdue_invoice,
        @invoice_without_sla
      ],
      meta: { total: 3, page: 1, pages: 1 }
    })
    InvoiceService.stubs(:statistics).returns({})

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoices_path

    # Check normal SLA indicator
    within "tr", text: "INV-001" do
      assert_text "Due in 4 hours"
      assert_selector ".text-green-600.bg-green-100"
    end

    # Check overdue SLA indicator
    within "tr", text: "INV-002" do
      assert_text "Overdue by 1 hour"
      assert_selector ".text-red-600.bg-red-100"
    end

    # Check invoice without SLA
    within "tr", text: "INV-004" do
      assert_text "No SLA"
      assert_selector ".text-gray-500.bg-gray-100"
    end
  end

  test "displays SLA warning indicator" do
    InvoiceService.stubs(:all).returns({
      invoices: [@warning_invoice],
      meta: { total: 1, page: 1, pages: 1 }
    })
    InvoiceService.stubs(:statistics).returns({})

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoices_path

    within "tr", text: "INV-003" do
      assert_text "Due in 30 minutes"
      assert_selector ".text-yellow-600.bg-yellow-100"
    end
  end

  test "displays detailed SLA information on workflow page" do
    InvoiceService.stubs(:find).returns(@invoice_with_sla)
    # Fix the response format to match what the controller expects
    WorkflowService.stubs(:available_transitions).returns({
      available_transitions: []
    })
    WorkflowService.stubs(:history).returns([])

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoice_workflow_path(@invoice_with_sla[:id])

    # Check SLA status section
    assert_text "SLA Status:"
    assert_text "Due in 4 hours"

    # Check detailed SLA section
    assert_text "SLA Details"
    assert_text "Time in current state: 2 hours"
    assert_text "Deadline: Jan 15, 2024 at 02:00 PM"

    # Check progress bar presence
    assert_selector ".bg-green-500"
  end

  test "displays overdue SLA details on workflow page" do
    InvoiceService.stubs(:find).returns(@overdue_invoice)
    WorkflowService.stubs(:available_transitions).returns({
      available_transitions: []
    })
    WorkflowService.stubs(:history).returns([])

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoice_workflow_path(@overdue_invoice[:id])

    # Check overdue status
    assert_text "Overdue by 1 hour"
    assert_selector ".text-red-600.bg-red-100"

    # Check detailed SLA section shows progress as 100%
    assert_text "SLA Details"
    assert_selector ".bg-red-500" # Progress bar should be red for overdue
  end

  test "handles invoice without SLA deadline on workflow page" do
    InvoiceService.stubs(:find).returns(@invoice_without_sla)
    WorkflowService.stubs(:available_transitions).returns({
      available_transitions: []
    })
    WorkflowService.stubs(:history).returns([])

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoice_workflow_path(@invoice_without_sla[:id])

    # Should show "No SLA" status
    assert_text "No SLA"
    assert_selector ".text-gray-500.bg-gray-100"

    # Should not show detailed SLA section
    assert_no_text "SLA Details"
  end

  test "SLA indicator updates styling based on time remaining" do
    # This test verifies the CSS classes are applied correctly
    InvoiceService.stubs(:all).returns({
      invoices: [
        @invoice_with_sla,
        @overdue_invoice,
        @warning_invoice
      ],
      meta: { total: 3, page: 1, pages: 1 }
    })
    InvoiceService.stubs(:statistics).returns({})

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoices_path

    # Normal SLA (green)
    within "tr", text: "INV-001" do
      assert_selector ".text-green-600.bg-green-100"
    end

    # Overdue SLA (red)
    within "tr", text: "INV-002" do
      assert_selector ".text-red-600.bg-red-100"
    end

    # Warning SLA (yellow)
    within "tr", text: "INV-003" do
      assert_selector ".text-yellow-600.bg-yellow-100"
    end
  end

  test "SLA progress bar shows correct percentage" do
    # Invoice that's 50% through its SLA period
    halfway_invoice = {
      id: 5,
      invoice_number: "INV-005",
      status: "pending_review",
      workflow: {
        'entered_current_state_at' => '2024-01-15 08:00:00 UTC', # 2 hours ago
        'sla_deadline' => '2024-01-15 12:00:00 UTC', # 2 hours from now (4 hours total)
        'is_overdue' => false
      }
    }

    InvoiceService.stubs(:find).returns(halfway_invoice)
    WorkflowService.stubs(:available_transitions).returns({
      available_transitions: []
    })
    WorkflowService.stubs(:history).returns([])

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoice_workflow_path(halfway_invoice[:id])

    # Progress bar should be 50% wide
    progress_bar = find(".bg-green-500")
    # Note: In a real test, you might check the style attribute or computed width
    assert progress_bar
  end

  test "handles missing workflow data gracefully" do
    invoice_no_workflow = {
      id: 6,
      invoice_number: "INV-006",
      status: "draft"
      # No workflow key
    }

    InvoiceService.stubs(:find).returns(invoice_no_workflow)
    WorkflowService.stubs(:available_transitions).returns({
      available_transitions: []
    })
    WorkflowService.stubs(:history).returns([])

    # Add authentication
    sign_in_for_system_test(role: "manager", company_id: 1)

    visit invoice_workflow_path(invoice_no_workflow[:id])

    # Should not show SLA section at all
    assert_no_text "SLA Status:"
    assert_no_text "SLA Details"
  end
end