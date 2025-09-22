# Service stubbing helpers for RSpec migration
# Incorporates successful patterns from Minitest system tests

module ServiceStubs
  # Mock all standard services with default responses
  def setup_standard_service_stubs
    setup_invoice_series_stubs
    setup_company_stubs
    setup_contact_stubs
    setup_workflow_stubs
  end

  # Invoice series service stubs
  def setup_invoice_series_stubs
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      },
      {
        id: 875,
        series_code: "PF",
        series_name: "Proforma",
        year: 2025,
        is_active: true
      },
      {
        id: 876,
        series_code: "CR",
        series_name: "Credit Note",
        year: 2025,
        is_active: true
      }
    ]

    allow(InvoiceSeriesService).to receive(:all).and_return(mock_invoice_series)
  end

  # Company service stubs
  def setup_company_stubs
    mock_companies = [
      { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." },
      { id: 2000, name: "TestCorp", legal_name: "Test Corporation Ltd." }
    ]

    allow(CompanyService).to receive(:all).and_return({ companies: mock_companies })
  end

  # Company contacts service stubs
  def setup_contact_stubs
    mock_contacts = [
      { id: 11, name: "abc", legal_name: "ABC Contact" },
      { id: 12, name: "xyz", legal_name: "XYZ Contact" }
    ]

    allow(CompanyContactsService).to receive(:all).and_return({ contacts: mock_contacts })
    allow(CompanyContactsService).to receive(:active_contacts).and_return(mock_contacts)
  end

  # Workflow service stubs
  def setup_workflow_stubs
    mock_workflows = [
      { id: 1, name: "Standard Approval", description: "Basic approval workflow" },
      { id: 2, name: "Complex Review", description: "Multi-step review process" }
    ]

    allow(WorkflowService).to receive(:definitions).and_return({ data: mock_workflows })
  end

  # Invoice service stubs
  def setup_invoice_service_stubs
    allow(InvoiceService).to receive(:recent).and_return([])
    allow(InvoiceService).to receive(:all).and_return({ invoices: [], meta: { total: 0 } })
    # Note: InvoiceService doesn't have a statistics method
  end

  # Stub successful invoice creation (used in form tests)
  def stub_successful_invoice_creation(invoice_id: "test_invoice_id")
    # Stub creation
    allow(InvoiceService).to receive(:create).and_return({
      data: { id: invoice_id }
    })

    # Stub show action for redirect
    allow(InvoiceService).to receive(:find).with(invoice_id, any_args).and_return({
      id: invoice_id,
      invoice_number: "FC-0001",
      status: "draft",
      total_amount: 100.0,
      buyer_company_contact_id: 11
    })
  end

  # Stub validation errors (used in error handling tests)
  def stub_invoice_validation_error(errors = { invoice_lines: ["can't be blank"] })
    allow(InvoiceService).to receive(:create).and_raise(
      ApiService::ValidationError.new("Validation failed", errors)
    )
  end

  # Stub workflow definition operations
  def stub_workflow_definition_operations
    allow(WorkflowService).to receive(:definition).and_return({
      id: 1,
      name: "Test Workflow",
      description: "Test workflow description",
      company_id: 1,
      is_active: true,
      is_global: false
    })

    allow(WorkflowService).to receive(:create_definition).and_return({
      id: 2,
      name: "New Workflow",
      description: "New workflow description"
    })

    allow(WorkflowService).to receive(:update_definition).and_return({
      id: 1,
      name: "Updated Workflow"
    })
  end

  # Stub validation error for workflow definitions
  def stub_workflow_validation_error(errors = { name: ["can't be blank"] })
    allow(WorkflowService).to receive(:create_definition).and_raise(
      ApiService::ValidationError.new("Validation failed", errors)
    )
  end

  # Helper to set up the most common stubs for feature specs
  def setup_feature_spec_stubs
    setup_standard_service_stubs
    setup_invoice_service_stubs
  end
end

RSpec.configure do |config|
  config.include ServiceStubs, type: :feature
  config.include ServiceStubs, type: :system
  config.include ServiceStubs, type: :request
  config.include ServiceStubs, type: :controller

  # Automatically set up basic stubs for feature specs
  config.before(:each, type: :feature) do
    setup_feature_spec_stubs
  end
end