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

  test "workflow show page displays transition state names correctly using state codes" do
    # Test the critical state code matching logic in the view
    # This addresses the "Any State to Unknown" issue reported by the user

    transitions_with_state_codes = [
      {
        id: 1,
        name: 'Submit for Review',
        code: 'submit',
        from_state_code: 'draft',      # Using state codes instead of IDs
        to_state_code: 'review',
        required_roles: []
      },
      {
        id: 2,
        name: 'Approve',
        code: 'approve',
        from_state_code: 'review',
        to_state_code: 'approved',
        required_roles: ['manager']
      },
      {
        id: 3,
        name: 'Reject',
        code: 'reject',
        from_state_code: 'review',
        to_state_code: 'draft',
        required_roles: ['manager']
      }
    ]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(transitions_with_state_codes)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Check that state names are correctly displayed in the page body
    # This tests that the state code matching logic is working properly
    assert response.body.include?("Draft"), "Should contain 'Draft' state name from code matching"
    assert response.body.include?("Under Review"), "Should contain 'Under Review' state name from code matching"
    assert response.body.include?("Approved"), "Should contain 'Approved' state name from code matching"

    # Most importantly: should NOT contain the problematic fallback text
    # This is the key test for the "Any State to Unknown" bug that was reported
    assert_not response.body.include?("Any State → Unknown"), "Should not show 'Any State → Unknown' when state codes match properly"

    # Verify the state code matching logic is working by checking that we're NOT seeing fallback text
    # Count how many times "Any State" appears - should be minimal since our states should match
    any_state_count = response.body.scan(/Any State/).length
    assert any_state_count <= 1, "Should have minimal 'Any State' fallbacks when state codes match (found #{any_state_count})"
  end

  test "workflow show page handles missing state codes gracefully" do
    # Test the edge case that causes "Any State to Unknown" display

    transitions_with_missing_state_codes = [
      {
        id: 1,
        name: 'Submit for Review',
        code: 'submit',
        from_state_code: nil,  # Missing from_state_code
        to_state_code: nil,    # Missing to_state_code
        required_roles: []
      },
      {
        id: 2,
        name: 'Invalid Transition',
        code: 'invalid',
        from_state_code: 'nonexistent',  # State code that doesn't exist
        to_state_code: 'also_nonexistent',
        required_roles: []
      }
    ]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(transitions_with_missing_state_codes)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Should gracefully show fallback text for missing/invalid state codes
    # This tests the edge case that was causing the "Any State to Unknown" issue
    assert response.body.include?("Any State"), "Should show 'Any State' fallback for missing from_state_code"
    assert response.body.include?("Unknown"), "Should show 'Unknown' fallback for missing to_state_code"
  end

  test "workflow show page handles mixed state code formats" do
    # Test with both symbol and string keys for state codes

    mixed_transitions = [
      {
        'id' => 1,
        'name' => 'Submit for Review',
        'code' => 'submit',
        'from_state_code' => 'draft',    # String key
        'to_state_code' => 'review',
        'required_roles' => []
      },
      {
        :id => 2,
        :name => 'Approve',
        :code => 'approve',
        :from_state_code => 'review',    # Symbol key
        :to_state_code => 'approved',
        :required_roles => ['manager']
      }
    ]

    mixed_states = [
      {
        'id' => 1,
        'name' => 'Draft',
        'code' => 'draft',     # String key
        'category' => 'draft'
      },
      {
        :id => 2,
        :name => 'Under Review',
        :code => 'review',     # Symbol key
        :category => 'review'
      },
      {
        'id' => 3,
        'name' => 'Approved',
        'code' => 'approved',  # String key
        'category' => 'approved'
      }
    ]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(mixed_states)
    WorkflowService.stubs(:definition_transitions).returns(mixed_transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Should handle both string and symbol keys correctly
    assert_select "span", text: "Draft"
    assert_select "span", text: "Under Review"
    assert_select "span", text: "Approved"
  end

  test "workflow show page state code matching is case sensitive" do
    # Test that state code matching is case sensitive

    case_sensitive_transitions = [
      {
        id: 1,
        name: 'Case Test',
        code: 'case_test',
        from_state_code: 'DRAFT',      # Uppercase - should not match 'draft'
        to_state_code: 'Review',       # Mixed case - should not match 'review'
        required_roles: []
      }
    ]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(case_sensitive_transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Should show fallback text due to case mismatch
    assert_select "span", text: "Any State"  # 'DRAFT' doesn't match 'draft'
    assert_select "span", text: "Unknown"    # 'Review' doesn't match 'review'
  end

  test "workflow show page performance with many states and transitions" do
    # Test performance and correctness with larger datasets

    many_states = (1..20).map do |i|
      {
        id: i,
        name: "State #{i}",
        code: "state_#{i}",
        category: 'test'
      }
    end

    many_transitions = (1..50).map do |i|
      from_index = (i % 19) + 1
      to_index = ((i + 1) % 19) + 1
      {
        id: i,
        name: "Transition #{i}",
        code: "trans_#{i}",
        from_state_code: "state_#{from_index}",
        to_state_code: "state_#{to_index}",
        required_roles: []
      }
    end

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(many_states)
    WorkflowService.stubs(:definition_transitions).returns(many_transitions)

    get workflow_definition_path(@workflow_definition[:id])

    assert_response :success

    # Should handle large datasets without errors
    # Check that at least some transitions display correctly
    assert_select "span", text: "State 1"
    assert_select "span", text: "State 2"

    # Should not contain error fallbacks
    assert_select "span", { text: "Any State", count: 0 }, "Should not show 'Any State' with valid state codes"
    assert_select "span", { text: "Unknown", count: 0 }, "Should not show 'Unknown' with valid state codes"
  end
end