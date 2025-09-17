require "test_helper"

class WorkflowViewFunctionalityTest < ActionDispatch::IntegrationTest
  setup do
    @user_token = "test_token_123"
    @workflow_definition = {
      id: 1,
      name: 'Test Workflow',
      code: 'TEST_WF',
      description: 'Test workflow for functionality testing',
      company_id: 1,
      is_active: true,
      is_default: false
    }
    @states = [
      {
        id: 1,
        name: 'Draft',
        code: 'draft',
        category: 'draft',
        color: '#6B7280',
        position: 1,
        is_initial: true,
        is_final: false,
        is_error: false
      },
      {
        id: 2,
        name: 'Under Review',
        code: 'review',
        category: 'review',
        color: '#F59E0B',
        position: 2,
        is_initial: false,
        is_final: false,
        is_error: false
      },
      {
        id: 3,
        name: 'Approved',
        code: 'approved',
        category: 'approved',
        color: '#10B981',
        position: 3,
        is_initial: false,
        is_final: true,
        is_error: false
      }
    ]
    @transitions = [
      {
        id: 1,
        name: 'Submit for Review',
        code: 'submit',
        from_state_id: 1,
        to_state_id: 2,
        required_roles: [],
        required_permissions: []
      },
      {
        id: 2,
        name: 'Approve',
        code: 'approve',
        from_state_id: 2,
        to_state_id: 3,
        required_roles: ['manager'],
        required_permissions: []
      },
      {
        id: 3,
        name: 'Reject',
        code: 'reject',
        from_state_id: 2,
        to_state_id: 1,
        required_roles: ['manager'],
        required_permissions: []
      }
    ]

    # Mock authentication
    ApplicationController.any_instance.stubs(:current_user_token).returns(@user_token)
    ApplicationController.any_instance.stubs(:authenticate_user!).returns(true)
    ApplicationController.any_instance.stubs(:current_company_id).returns(1)
  end

  test "workflow show page displays states correctly with symbol keys" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check that workflow details are displayed
    assert_select "h1", text: @workflow_definition[:name]

    # Check that states are displayed (specific to states section)
    assert_select ".grid.grid-cols-1.md\\:grid-cols-2 .border.rounded-lg", count: @states.count
    @states.each do |state|
      assert_select "div", text: state[:name]
      assert_select "div", text: state[:code]
    end

    # Check initial state is highlighted
    initial_state = @states.find { |s| s[:is_initial] }
    assert_select ".border-green-200.bg-green-50"

    # Check final state badge is shown
    final_state = @states.find { |s| s[:is_final] }
    assert_select "span.bg-blue-100.text-blue-800", text: "End"
  end

  test "workflow show page displays transitions correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check that transitions are displayed (specific to transitions section)
    assert_select ".space-y-3 > .border.rounded-lg", count: @transitions.count

    @transitions.each do |transition|
      assert_select "div", text: transition[:name]
    end

    # Check required roles are displayed
    manager_transition = @transitions.find { |t| t[:required_roles].include?('manager') }
    assert_select "span.bg-blue-100.text-blue-800", text: /Role:.*manager/i
  end

  test "workflow show page includes management buttons" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check "Add State" button is present
    assert_select "a[href*='workflow_states/new']", text: "Add State"

    # Check "Add Transition" button is present
    assert_select "a[href*='workflow_transitions/new']", text: "Add Transition"

    # Check edit buttons for each state
    @states.each do |state|
      assert_select "a[href*='workflow_states/#{state[:id]}/edit']"
    end

    # Check delete buttons for each state
    @states.each do |state|
      assert_select "a[href*='workflow_states/#{state[:id]}'][data-method='delete']"
    end
  end

  test "workflow show page handles empty states and transitions" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns([])
    WorkflowService.stubs(:definition_transitions).returns([])

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Should still show add buttons even with no states/transitions
    assert_select "a[href*='workflow_states/new']", text: "Add State"
    assert_select "a[href*='workflow_transitions/new']", text: "Add Transition"

    # Should show empty transitions message
    assert_select "p", text: /No transitions defined for this workflow/
  end

  test "workflow show page handles API errors gracefully" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).raises(ApiService::ApiError.new("States not found"))
    WorkflowService.stubs(:definition_transitions).raises(ApiService::ApiError.new("Transitions not found"))

    get workflow_definition_path(@workflow_definition[:id])

    assert_redirected_to workflow_definitions_path
    assert_match /Failed to load workflow details/, flash[:error]
  end

  test "workflow edit page form handles symbol keys correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    get edit_workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check form fields are populated with symbol key values
    assert_select "input[name='workflow_definition[name]'][value='#{@workflow_definition[:name]}']"
    assert_select "input[name='workflow_definition[code]'][value='#{@workflow_definition[:code]}']"
    assert_select "textarea[name='workflow_definition[description]']", text: @workflow_definition[:description]

    # Check boolean fields
    if @workflow_definition[:is_active]
      assert_select "input[name='workflow_definition[is_active]'][type='checkbox'][checked]"
    end

    if @workflow_definition[:is_default]
      assert_select "input[name='workflow_definition[is_default]'][type='checkbox'][checked]"
    end
  end

  test "workflow edit page form submission works with symbol keys" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    updated_definition = @workflow_definition.merge(name: 'Updated Workflow Name')
    WorkflowService.stubs(:update_definition).returns(updated_definition)

    patch workflow_definition_path(@workflow_definition[:id]), params: {
      workflow_definition: {
        name: 'Updated Workflow Name',
        code: @workflow_definition[:code],
        description: @workflow_definition[:description],
        is_active: @workflow_definition[:is_active],
        is_default: @workflow_definition[:is_default]
      }
    }

    assert_redirected_to workflow_definition_path(updated_definition[:id])
    assert_match /updated successfully/, flash[:success]
  end

  test "workflow show page displays state categories correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check category badges are displayed for each state
    @states.each do |state|
      if state[:category]
        assert_select "span.bg-gray-100.text-gray-700", text: state[:category].humanize
      end
    end
  end

  test "workflow show page handles string key responses from API" do
    # Test with string keys (original format)
    string_definition = @workflow_definition.transform_keys(&:to_s)
    string_states = @states.map { |s| s.transform_keys(&:to_s) }
    string_transitions = @transitions.map { |t| t.transform_keys(&:to_s) }

    WorkflowService.stubs(:definition).returns(string_definition)
    WorkflowService.stubs(:definition_states).returns(string_states)
    WorkflowService.stubs(:definition_transitions).returns(string_transitions)

    get workflow_definition_path(string_definition['id'])

    assert_response :success

    # Should work the same as with symbol keys
    assert_select "h1", text: string_definition['name']
    assert_select ".grid.grid-cols-1.md\\:grid-cols-2 .border.rounded-lg", count: string_states.count
  end
end