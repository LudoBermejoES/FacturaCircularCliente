require "test_helper"

class WorkflowTransitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workflow_definition = {
      'id' => 1,
      'name' => 'Standard Invoice Workflow',
      'description' => 'Default workflow for invoice processing',
      'company_id' => 1,
      'is_active' => true,
      'is_global' => false
    }

    @workflow_states = [
      {
        'id' => 1,
        'name' => 'draft',
        'display_name' => 'Draft',
        'category' => 'draft',
        'color' => '#gray',
        'position' => 1,
        'is_initial' => true,
        'is_final' => false
      },
      {
        'id' => 2,
        'name' => 'approved',
        'display_name' => 'Approved',
        'category' => 'approved',
        'color' => '#green',
        'position' => 2,
        'is_initial' => false,
        'is_final' => true
      }
    ]

    @workflow_transition = {
      'id' => 1,
      'name' => 'approve',
      'display_name' => 'Approve Invoice',
      'from_state_id' => 1,
      'to_state_id' => 2,
      'required_roles' => ['manager'],
      'requires_comment' => true,
      'guard_conditions' => ['total_amount > 100']
    }

    @workflow_transitions = [
      @workflow_transition,
      {
        'id' => 2,
        'name' => 'reject',
        'display_name' => 'Reject Invoice',
        'from_state_id' => 1,
        'to_state_id' => 1,
        'required_roles' => [],
        'requires_comment' => true,
        'guard_conditions' => []
      }
    ]

    # Setup authenticated session using the test helper
    setup_authenticated_session(role: "admin", company_id: 1)
  end

  test "should get index" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_transitions).returns(@workflow_transitions)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get workflow_definition_workflow_transitions_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_transitions)
    assert_not_nil assigns(:workflow_states)
    assert_not_nil assigns(:workflow_definition)
    assert_equal 2, assigns(:workflow_transitions).size
  end

  test "should handle API error on index" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_transitions).raises(ApiService::ApiError.new("API Error"))
    WorkflowService.stubs(:definition_states).returns([])

    get workflow_definition_workflow_transitions_url(@workflow_definition['id'])
    assert_response :success
    assert_equal [], assigns(:workflow_transitions)
    assert_equal [], assigns(:workflow_states)
    assert_match /Failed to load workflow transitions/, flash[:error]
  end

  test "should redirect if workflow definition not found" do
    WorkflowService.stubs(:definition).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_workflow_transitions_url(999)
    assert_redirected_to workflow_definitions_path
    assert_match /Workflow definition not found/, flash[:error]
  end

  test "should get show" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_transition)
    assert_not_nil assigns(:workflow_states)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should redirect on show with invalid transition id" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_workflow_transition_url(@workflow_definition['id'], 999)
    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_match /Workflow transition not found/, flash[:error]
  end

  test "should get new" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get new_workflow_definition_workflow_transition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_transition)
    assert_not_nil assigns(:workflow_states)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should handle error loading states for new" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).raises(ApiService::ApiError.new("API Error"))

    get new_workflow_definition_workflow_transition_url(@workflow_definition['id'])
    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_match /Failed to load workflow states/, flash[:error]
  end

  test "should create workflow transition" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    new_transition = @workflow_transition.merge('id' => 3, 'name' => 'review', 'code' => 'review')
    WorkflowService.stubs(:create_transition).returns(new_transition)

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'review',
        code: 'review',
        display_name: 'Send for Review',
        from_state_id: 1,
        to_state_id: 2,
        required_roles: ['admin', 'manager'],
        requires_comment: true,
        guard_conditions: ['amount > 500']
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition created successfully', flash[:success]
  end

  test "should handle create errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:create_transition).raises(ApiService::ApiError.new("Validation error"))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: '',
        display_name: ''
      }
    }

    assert_response :unprocessable_content
    assert_template :new
    assert_match /Failed to create workflow transition/, flash[:error]
  end

  test "should get edit" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get edit_workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_transition)
    assert_not_nil assigns(:workflow_states)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should update workflow transition" do
    updated_transition = @workflow_transition.merge('display_name' => 'Updated Approve')
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:update_transition).returns(updated_transition)

    patch workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id']), params: {
      workflow_transition: {
        display_name: 'Updated Approve'
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition updated successfully', flash[:success]
  end

  test "should handle update errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:update_transition).raises(ApiService::ApiError.new("Validation error"))

    patch workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id']), params: {
      workflow_transition: {
        name: ''
      }
    }

    assert_response :unprocessable_content
    assert_template :edit
    assert_match /Failed to update workflow transition/, flash[:error]
  end

  test "should destroy workflow transition" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:delete_transition).returns(true)

    delete workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition deleted successfully', flash[:success]
  end

  test "should handle destroy errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:delete_transition).raises(ApiService::ApiError.new("Cannot delete"))

    delete workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_match /Failed to delete workflow transition/, flash[:error]
  end

  test "workflow transition params filtering and processing" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test parameter processing - empty strings should be converted to nil, arrays should be filtered
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        'name' => 'test',
        'code' => 'test_code',
        'display_name' => 'Test',
        'from_state_id' => nil, # Empty string should be converted to nil
        'to_state_id' => '2',
        'requires_comment' => '1', # Checkbox value
        'required_roles' => ['admin'], # Empty strings filtered out
        'guard_conditions' => ['amount > 100'] # Empty strings filtered out
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'test',
        code: 'test_code',
        display_name: 'Test',
        from_state_id: '', # Should be converted to nil
        to_state_id: '2',
        requires_comment: '1',
        required_roles: ['admin', ''], # Empty string should be filtered out
        guard_conditions: ['amount > 100', ''], # Empty string should be filtered out
        # These should be filtered out
        invalid_param: 'should_be_ignored',
        id: 'should_be_ignored'
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  test "should handle empty required_roles and guard_conditions arrays" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        'required_roles' => [],
        'guard_conditions' => []
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'test',
        code: 'test',
        display_name: 'Test',
        from_state_id: '1',
        to_state_id: '2',
        required_roles: [''], # Only empty strings
        guard_conditions: [''] # Only empty strings
      }
    }

    assert_response :redirect
  end

  test "should require code parameter for create" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:create_transition).raises(ApiService::ApiError.new("Code can't be blank"))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'test',
        display_name: 'Test',
        from_state_id: '1',
        to_state_id: '2'
        # Missing code parameter
      }
    }

    assert_response :unprocessable_content
    assert_template :new
    assert_match /Failed to create workflow transition/, flash[:error]
  end

  test "should handle symbol and string keys for workflow states data" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test with Hash containing :data key (symbolized)
    states_hash = { data: @workflow_states }
    WorkflowService.stubs(:definition_states).returns(states_hash)

    get new_workflow_definition_workflow_transition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_states)

    # Test with Hash containing 'data' key (string)
    states_hash_string = { 'data' => @workflow_states }
    WorkflowService.stubs(:definition_states).returns(states_hash_string)

    get new_workflow_definition_workflow_transition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_states)

    # Test with direct array
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get new_workflow_definition_workflow_transition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_states)
  end

  test "should handle workflow transition with all required fields" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    complete_transition = @workflow_transition.merge({
      'id' => 10,
      'name' => 'complete_review',
      'code' => 'complete_review',
      'display_name' => 'Complete Review Process',
      'from_state_id' => 1,
      'to_state_id' => 2,
      'required_roles' => ['admin', 'manager'],
      'requires_comment' => true,
      'guard_conditions' => ['amount > 1000', 'status == "ready"']
    })

    WorkflowService.stubs(:create_transition).returns(complete_transition)

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'complete_review',
        code: 'complete_review',
        display_name: 'Complete Review Process',
        from_state_id: 1,
        to_state_id: 2,
        required_roles: ['admin', 'manager'],
        requires_comment: '1',
        guard_conditions: ['amount > 1000', 'status == "ready"']
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition created successfully', flash[:success]
  end

  test "should handle flat parameter format in workflow_transition_params" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test flat parameter format (not nested under workflow_transition)
    # Based on the controller logic, flat parameters are only used when workflow_transition doesn't have the expected keys
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :name => 'flat_test',
        :code => 'flat_test_code',
        :display_name => 'Flat Test',
        :from_state_id => '1',
        :to_state_id => '2',
        :required_roles => ['admin'],
        :guard_conditions => []
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    # Send flat parameters - workflow_transition should not contain display_name key to trigger flat logic
    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      name: 'flat_test',
      code: 'flat_test_code',
      display_name: 'Flat Test',
      from_state_id: '1',
      to_state_id: '2',
      required_roles: ['admin'],
      workflow_transition: { guard_conditions: [] } # No display_name key here
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  test "should find from_state and to_state for show action" do
    # Add state codes to test state finding logic
    workflow_transition_with_codes = @workflow_transition.merge({
      'from_state_code' => 'draft',
      'to_state_code' => 'approved'
    })

    states_with_codes = [
      {
        'id' => 1,
        'name' => 'draft',
        'code' => 'draft',
        'display_name' => 'Draft'
      },
      {
        'id' => 2,
        'name' => 'approved',
        'code' => 'approved',
        'display_name' => 'Approved'
      }
    ]

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(workflow_transition_with_codes)
    WorkflowService.stubs(:definition_states).returns(states_with_codes)

    get workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])

    assert_response :success
    assert_not_nil assigns(:from_state)
    assert_not_nil assigns(:to_state)
    assert_equal 'draft', assigns(:from_state)['code']
    assert_equal 'approved', assigns(:to_state)['code']
  end

  test "should handle missing from_state and to_state codes in show action" do
    # Test with transition that has no state codes
    transition_without_codes = @workflow_transition.dup
    transition_without_codes.delete('from_state_code')
    transition_without_codes.delete('to_state_code')

    # Use empty states array so find returns nil
    empty_states = []

    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(transition_without_codes)
    WorkflowService.stubs(:definition_states).returns(empty_states)

    get workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])

    assert_response :success
    assert_nil assigns(:from_state)
    assert_nil assigns(:to_state)
  end

  test "should handle both hash response formats for transitions and states" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test with different hash format - 'workflow_transitions' key
    transitions_hash = { 'workflow_transitions' => @workflow_transitions }
    states_hash = { 'workflow_states' => @workflow_states }

    WorkflowService.stubs(:definition_transitions).returns(transitions_hash)
    WorkflowService.stubs(:definition_states).returns(states_hash)

    get workflow_definition_workflow_transitions_url(@workflow_definition['id'])

    assert_response :success
    assert_equal @workflow_transitions, assigns(:workflow_transitions)
    assert_equal @workflow_states, assigns(:workflow_states)
  end

  test "should handle invalid response formats gracefully" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test with completely invalid response format
    WorkflowService.stubs(:definition_transitions).returns(nil)
    WorkflowService.stubs(:definition_states).returns("invalid_string")

    get workflow_definition_workflow_transitions_url(@workflow_definition['id'])

    assert_response :success
    assert_equal [], assigns(:workflow_transitions)
    assert_equal [], assigns(:workflow_states)
  end

  test "should handle edit action API errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:definition_states).raises(ApiService::ApiError.new("States error"))

    get edit_workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_match /Workflow transition not found/, flash[:error]
  end

  test "should preserve workflow_transition data on create failure" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:create_transition).raises(ApiService::ApiError.new("Validation failed"))

    transition_params = {
      name: 'test_fail',
      code: 'test_fail_code',
      display_name: 'Test Fail',
      from_state_id: '1',
      to_state_id: '2',
      required_roles: ['admin'],
      requires_comment: '1'
    }

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: transition_params
    }

    assert_response :unprocessable_content
    assert_template :new

    # Check that the form data is preserved
    assigned_transition = assigns(:workflow_transition)
    assert_equal 'test_fail', assigned_transition['name']
    assert_equal 'test_fail_code', assigned_transition['code']
    assert_equal 'Test Fail', assigned_transition['display_name']
  end

  test "should handle boolean conversion for requires_comment" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test different boolean formats
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries('requires_comment' => 'false'),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        name: 'bool_test',
        code: 'bool_test',
        display_name: 'Boolean Test',
        from_state_id: '1',
        to_state_id: '2',
        requires_comment: 'false' # Should preserve as string
      }
    }

    assert_response :redirect
  end

  test "should handle mixed parameter formats in update" do
    updated_transition = @workflow_transition.merge('display_name' => 'Mixed Update')
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)
    WorkflowService.stubs(:update_transition).returns(updated_transition)

    # Test update with mixed nested and flat parameters
    patch workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id']), params: {
      display_name: 'Mixed Update', # Flat parameter
      workflow_transition: {
        guard_conditions: ['new_condition'] # Nested parameter
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition updated successfully', flash[:success]
  end
end