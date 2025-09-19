require "application_system_test_case"

class WorkflowVisualizationSimplifiedTest < ApplicationSystemTestCase
  setup do
    # Mock basic workflow data that the controller needs
    mock_workflow = {
      'id' => 1,
      'name' => 'Test Workflow',
      'description' => 'Test workflow for visualization',
      'company_id' => 1,
      'is_active' => true,
      'is_global' => false,
      'version' => 1,
      'created_at' => '2024-01-01T00:00:00Z'
    }

    # Mock the service calls the controller makes
    WorkflowService.stubs(:definition).returns(mock_workflow)
    WorkflowService.stubs(:definition_states).returns([])
    WorkflowService.stubs(:definition_transitions).returns([])
  end

  test "workflow definition page loads with basic structure" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit workflow_definition_path(1)

    # Basic page structure tests
    assert_text "Test Workflow"
    assert_text "Workflow Visualization"
    assert_text "Workflow Details"

    # Should have states and transitions sections
    assert_text "States"
    assert_text "Transitions"
  end

  test "workflow page shows workflow details section" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit workflow_definition_path(1)

    # Check basic workflow information is displayed
    assert_text "Test Workflow"
    assert_text "Test workflow for visualization"
    assert_text "Status"
    assert_text "Type"
    assert_text "Version"
  end

  test "workflow page has proper navigation and structure" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit workflow_definition_path(1)

    # Verify page has basic navigation and structure
    assert_selector "main" # Main content area
    assert_text "FacturaCircular" # Site header
    assert_text "Dashboard" # Navigation item

    # Basic workflow page structure
    assert_text "Workflow Visualization"
  end

  test "workflow page handles empty states gracefully" do
    sign_in_for_system_test(role: "admin", company_id: 1)
    visit workflow_definition_path(1)

    # When no states are defined, should show appropriate message
    assert_text "No states defined"
    assert_text "No transitions defined"

    # Should have buttons to add states/transitions
    assert_text "Add State"
    assert_text "Add Transition"
  end
end