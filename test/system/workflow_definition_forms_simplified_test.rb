require "application_system_test_case"

class WorkflowDefinitionFormsSimplifiedTest < ApplicationSystemTestCase
  setup do
    # Mock services to prevent API calls
    mock_company = { id: 1, name: "Test Company" }
    mock_workflow = {
      id: 1,
      name: "Test Workflow",
      code: "test_wf",
      description: "Test workflow",
      company_id: 1,
      is_active: true,
      is_default: false
    }

    CompanyService.stubs(:all).returns({ companies: [mock_company] })
    WorkflowService.stubs(:definition).returns(mock_workflow)
    WorkflowService.stubs(:create_definition).returns({ data: mock_workflow })
    WorkflowService.stubs(:update_definition).returns({ data: mock_workflow })
  end

  test "new workflow definition form loads with basic structure" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit new_workflow_definition_path

    # Basic form structure
    assert_text "New Workflow Definition"
    assert_field "Name"
    assert_field "Code"
    assert_field "Description"

    # Form controls
    assert_button "Create Workflow Definition"
    assert_link "Cancel"
  end

  test "edit workflow definition form loads with basic structure" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit edit_workflow_definition_path(1)

    # Basic form structure
    assert_text "Edit Workflow Definition"
    assert_field "Name"
    assert_field "Code"
    assert_field "Description"

    # Form controls
    assert_button "Update Workflow Definition"
    assert_link "Cancel"
  end

  test "form has proper validation structure" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit new_workflow_definition_path

    # Verify required fields exist
    name_field = find_field("Name")
    code_field = find_field("Code")

    assert name_field
    assert code_field

    # Basic form interaction test
    fill_in "Name", with: "Test Workflow"
    fill_in "Code", with: "test_code"
    fill_in "Description", with: "Test description"

    # Form should accept input
    assert_field "Name", with: "Test Workflow"
    assert_field "Code", with: "test_code"
  end

  test "form fields are properly accessible" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit new_workflow_definition_path

    # Check form accessibility and structure
    assert_selector "form"
    assert_selector "input[type='text']", minimum: 2
    assert_selector "textarea", minimum: 1

    # Verify form has proper labels
    assert_text "Name"
    assert_text "Code"
    assert_text "Description"
  end
end