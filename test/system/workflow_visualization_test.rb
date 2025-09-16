require "application_system_test_case"

class WorkflowVisualizationTest < ApplicationSystemTestCase
  setup do
    @workflow_definition = {
      'id' => 1,
      'name' => 'Test Workflow',
      'description' => 'Test workflow for visualization',
      'company_id' => 1,
      'is_active' => true,
      'is_global' => false,
      'version' => 1,
      'created_at' => '2024-01-01T00:00:00Z'
    }

    @states = [
      {
        'id' => 1,
        'name' => 'draft',
        'display_name' => 'Draft',
        'category' => 'draft',
        'color' => '#gray',
        'position' => 1,
        'is_initial' => true,
        'is_final' => false,
        'is_error' => false
      },
      {
        'id' => 2,
        'name' => 'review',
        'display_name' => 'Under Review',
        'category' => 'review',
        'color' => '#yellow',
        'position' => 2,
        'is_initial' => false,
        'is_final' => false,
        'is_error' => false
      },
      {
        'id' => 3,
        'name' => 'approved',
        'display_name' => 'Approved',
        'category' => 'approved',
        'color' => '#green',
        'position' => 3,
        'is_initial' => false,
        'is_final' => true,
        'is_error' => false
      }
    ]

    @transitions = [
      {
        'id' => 1,
        'from_state_id' => 1,
        'to_state_id' => 2,
        'name' => 'submit',
        'display_name' => 'Submit for Review',
        'required_roles' => ['employee'],
        'requires_comment' => false
      },
      {
        'id' => 2,
        'from_state_id' => 2,
        'to_state_id' => 3,
        'name' => 'approve',
        'display_name' => 'Approve',
        'required_roles' => ['manager'],
        'requires_comment' => true
      }
    ]

    # Mock authentication
    ApplicationController.any_instance.stubs(:require_authentication).returns(true)
    ApplicationController.any_instance.stubs(:current_user_token).returns("test_token")
  end

  test "displays workflow visualization on workflow definition show page" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    visit workflow_definition_path(@workflow_definition['id'])

    assert_text "Workflow Visualization"
    assert_text "3 states, 2 transitions"

    # Check that the workflow diagram container is present
    assert_selector "[data-controller='workflow-diagram']"
    assert_selector "svg[data-workflow-diagram-target='canvas']"

    # Check workflow details are displayed
    assert_text @workflow_definition['name']
    assert_text @workflow_definition['description']
    assert_text "Active"
    assert_text "Company Specific"
  end

  test "displays states information correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    visit workflow_definition_path(@workflow_definition['id'])

    # Check states section
    within "h3", text: "States" do
      # States section should be present
    end

    # Check each state is displayed
    @states.each do |state|
      assert_text state['display_name']
      assert_text state['name']
    end

    # Check start/end badges
    assert_text "Start" # For initial state
    assert_text "End"   # For final state
  end

  test "displays transitions information correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    visit workflow_definition_path(@workflow_definition['id'])

    # Check transitions section
    within "h3", text: "Transitions" do
      # Transitions section should be present
    end

    # Check each transition is displayed
    @transitions.each do |transition|
      assert_text transition['display_name']
    end

    # Check role requirements
    assert_text "Role: Employee"
    assert_text "Role: Manager"
    assert_text "Comment Required"
  end

  test "handles workflow definition with no states" do
    empty_workflow = @workflow_definition.dup
    WorkflowService.stubs(:definition).returns(empty_workflow)
    WorkflowService.stubs(:definition_states).returns([])
    WorkflowService.stubs(:definition_transitions).returns([])

    visit workflow_definition_path(empty_workflow['id'])

    assert_text "Workflow Visualization"
    assert_text "0 states, 0 transitions"

    # Should not display the diagram when no states
    assert_no_selector "[data-controller='workflow-diagram']"
    assert_text "No transitions defined for this workflow"
  end

  test "handles workflow definition with single state" do
    single_state = [@states.first]
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(single_state)
    WorkflowService.stubs(:definition_transitions).returns([])

    visit workflow_definition_path(@workflow_definition['id'])

    assert_text "1 states, 0 transitions"
    assert_selector "[data-controller='workflow-diagram']"
    assert_text single_state.first['display_name']
  end

  test "shows error state indicator" do
    error_state = {
      'id' => 4,
      'name' => 'error',
      'display_name' => 'Error State',
      'category' => 'error',
      'color' => '#red',
      'position' => 4,
      'is_initial' => false,
      'is_final' => false,
      'is_error' => true
    }

    states_with_error = @states + [error_state]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(states_with_error)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    visit workflow_definition_path(@workflow_definition['id'])

    assert_text "Error State"
    assert_text "Error" # Badge text
  end

  test "workflow diagram includes proper JSON data attributes" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    visit workflow_definition_path(@workflow_definition['id'])

    # Check that the diagram has the expected data attributes
    diagram_element = find("[data-controller='workflow-diagram']")

    # The states and transitions data should be present as JSON
    assert diagram_element["data-workflow-diagram-states-value"]
    assert diagram_element["data-workflow-diagram-transitions-value"]
    assert_equal "700", diagram_element["data-workflow-diagram-width-value"]
    assert_equal "300", diagram_element["data-workflow-diagram-height-value"]
  end
end