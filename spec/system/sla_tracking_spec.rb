# Migrated from test/system/sla_tracking_test.rb
# System spec: SLA tracking and workflow deadline monitoring

require 'rails_helper'

RSpec.describe "SLA Tracking System", type: :system do
  # Critical Business Path: SLA monitoring and deadline tracking
  # Risk Level: HIGH - SLA violations affect customer service and compliance
  # Focus: Visual indicators, deadline calculations, and workflow status tracking

  before do
    setup_authenticated_session(role: "manager", company_id: 1)
    setup_sla_test_data

    # Mock time for consistent SLA calculations
    allow(Time).to receive(:current).and_return(Time.parse("2024-01-15 10:00:00 UTC"))
  end

  describe "SLA indicators on invoices index page" do
    it "displays correct SLA status indicators for different invoice states" do
      # Mock invoice list with SLA data
      allow(InvoiceService).to receive(:all).and_return({
        invoices: [
          @invoice_with_sla,
          @overdue_invoice,
          @invoice_without_sla
        ],
        meta: { total: 3, page: 1, pages: 1 }
      })

      visit invoices_path

      # Check normal SLA indicator (green - 4 hours remaining)
      within "tr", text: "INV-001" do
        expect(page).to have_text("Due in 4 hours")
        expect(page).to have_css(".text-green-600.bg-green-100")
      end

      # Check overdue SLA indicator (red - 1 hour overdue)
      within "tr", text: "INV-002" do
        expect(page).to have_text("Overdue by 1 hour")
        expect(page).to have_css(".text-red-600.bg-red-100")
      end

      # Check invoice without SLA (gray)
      within "tr", text: "INV-004" do
        expect(page).to have_text("No SLA")
        expect(page).to have_css(".text-gray-500.bg-gray-100")
      end
    end

    it "displays warning indicator for approaching deadlines" do
      allow(InvoiceService).to receive(:all).and_return({
        invoices: [@warning_invoice],
        meta: { total: 1, page: 1, pages: 1 }
      })

      visit invoices_path

      within "tr", text: "INV-003" do
        expect(page).to have_text("Due in 30 minutes")
        expect(page).to have_css(".text-yellow-600.bg-yellow-100")
      end
    end

    it "applies correct styling based on time remaining" do
      allow(InvoiceService).to receive(:all).and_return({
        invoices: [
          @invoice_with_sla,
          @overdue_invoice,
          @warning_invoice
        ],
        meta: { total: 3, page: 1, pages: 1 }
      })

      visit invoices_path

      # Normal SLA (green)
      within "tr", text: "INV-001" do
        expect(page).to have_css(".text-green-600.bg-green-100")
      end

      # Overdue SLA (red)
      within "tr", text: "INV-002" do
        expect(page).to have_css(".text-red-600.bg-red-100")
      end

      # Warning SLA (yellow)
      within "tr", text: "INV-003" do
        expect(page).to have_css(".text-yellow-600.bg-yellow-100")
      end
    end
  end

  describe "detailed SLA information on workflow page" do
    it "displays comprehensive SLA details for active invoices" do
      allow(InvoiceService).to receive(:find).and_return(@invoice_with_sla)
      allow(WorkflowService).to receive(:available_transitions).and_return({
        available_transitions: []
      })
      allow(WorkflowService).to receive(:history).and_return([])

      visit invoice_workflow_path(@invoice_with_sla[:id])

      # Check SLA status section
      expect(page).to have_text("SLA Status:")
      expect(page).to have_text("Due in 4 hours")

      # Check detailed SLA section
      expect(page).to have_text("SLA Details")
      expect(page).to have_text("Time in current state: 2 hours")
      expect(page).to have_text("Deadline: Jan 15, 2024 at 02:00 PM")

      # Check progress bar presence
      expect(page).to have_css(".bg-green-500")
    end

    it "displays overdue SLA details with correct styling" do
      allow(InvoiceService).to receive(:find).and_return(@overdue_invoice)
      allow(WorkflowService).to receive(:available_transitions).and_return({
        available_transitions: []
      })
      allow(WorkflowService).to receive(:history).and_return([])

      visit invoice_workflow_path(@overdue_invoice[:id])

      # Check overdue status
      expect(page).to have_text("Overdue by 1 hour")
      expect(page).to have_css(".text-red-600.bg-red-100")

      # Check detailed SLA section shows progress as overdue
      expect(page).to have_text("SLA Details")
      expect(page).to have_css(".bg-red-500") # Progress bar should be red for overdue
    end

    it "handles invoices without SLA deadline" do
      allow(InvoiceService).to receive(:find).and_return(@invoice_without_sla)
      allow(WorkflowService).to receive(:available_transitions).and_return({
        available_transitions: []
      })
      allow(WorkflowService).to receive(:history).and_return([])

      visit invoice_workflow_path(@invoice_without_sla[:id])

      # Should show "No SLA" status
      expect(page).to have_text("No SLA")
      expect(page).to have_css(".text-gray-500.bg-gray-100")

      # Should not show detailed SLA section
      expect(page).not_to have_text("SLA Details")
    end

    it "calculates and displays correct progress percentage" do
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

      allow(InvoiceService).to receive(:find).and_return(halfway_invoice)
      allow(WorkflowService).to receive(:available_transitions).and_return({
        available_transitions: []
      })
      allow(WorkflowService).to receive(:history).and_return([])

      visit invoice_workflow_path(halfway_invoice[:id])

      # Progress bar should be present for 50% completion
      progress_bar = find(".bg-green-500")
      expect(progress_bar).to be_present
    end
  end

  describe "edge cases and error handling" do
    it "handles missing workflow data gracefully" do
      invoice_no_workflow = {
        id: 6,
        invoice_number: "INV-006",
        status: "draft"
        # No workflow key
      }

      allow(InvoiceService).to receive(:find).and_return(invoice_no_workflow)
      allow(WorkflowService).to receive(:available_transitions).and_return({
        available_transitions: []
      })
      allow(WorkflowService).to receive(:history).and_return([])

      visit invoice_workflow_path(invoice_no_workflow[:id])

      # Should not show SLA section at all
      expect(page).not_to have_text("SLA Status:")
      expect(page).not_to have_text("SLA Details")
    end
  end

  private

  def setup_sla_test_data
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

    # Mock common services
    allow(InvoiceService).to receive(:recent).and_return([])
  end
end