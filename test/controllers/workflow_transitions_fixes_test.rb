require "test_helper"

class WorkflowTransitionsFixesTest < ActionDispatch::IntegrationTest
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

    # Setup authenticated session using the test helper
    setup_authenticated_session(role: "admin", company_id: 1)
  end

  test "should handle create with proper parameter mapping and avoid API validation errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Mock successful creation with the expected parameter format
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :name => 'test_transition',
        :code => 'test_transition',
        :display_name => 'Test Transition',
        :from_state_id => nil,  # "Any State" should map to nil
        :to_state_id => '2',
        :requires_comment => true,
        :required_roles => [],
        :guard_conditions => []
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    # Submit form with parameters that should trigger the API parameter mapping fix
    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        display_name: 'Test Transition',
        name: 'test_transition',
        from_state_id: '', # Empty should map to nil for "Any State"
        to_state_id: '2',
        requires_comment: '1',
        required_roles: [],
        guard_conditions: []
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition created successfully', flash[:success]
  end

  test "should handle edit view without Ruby type conversion errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Mock transition with proper state codes for testing the view fix
    transition_with_codes = @workflow_transition.merge({
      'from_state_code' => 'draft',
      'to_state_code' => 'approved'
    })
    WorkflowService.stubs(:get_transition).returns(transition_with_codes)

    get edit_workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id'])
    assert_response :success

    # The page should load without the "undefined method 'split' for nil" error
    assert_select "input[name='workflow_transition[display_name]']"
    assert_select "select[name='workflow_transition[to_state_id]']"
  end

  test "should handle update with correct parameter processing" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)

    # Mock successful update with properly processed parameters
    WorkflowService.expects(:update_transition).with(
      @workflow_definition['id'],
      @workflow_transition['id'],
      has_entries(
        :name => 'updated_approve',
        :code => 'updated_approve',
        :display_name => 'Updated Approve Invoice',
        :requires_comment => false,
        :required_roles => [],
        :guard_conditions => []
      ),
      token: anything
    ).returns(@workflow_transition)

    patch workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id']), params: {
      workflow_transition: {
        display_name: 'Updated Approve Invoice',
        name: 'updated_approve',
        requires_comment: '0', # Should convert to false
        required_roles: [],
        guard_conditions: []
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
    assert_equal 'Workflow transition updated successfully', flash[:success]
  end

  test "should handle parameter name/code generation correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Test that code is auto-generated from name when missing
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :name => 'Complex Transition Name',
        :code => 'complex_transition_name',  # Auto-generated from name
        :display_name => 'Complex Transition Name'
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        display_name: 'Complex Transition Name',
        name: 'Complex Transition Name',
        # No code provided - should be auto-generated
        from_state_id: '1',
        to_state_id: '2',
        requires_comment: '0',
        required_roles: [],
        guard_conditions: []
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  test "should handle mixed parameter formats for backward compatibility" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Test the specific scenario that was failing - flat parameters with partial nested
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :name => 'mixed_test',
        :code => 'mixed_code',
        :display_name => 'Mixed Test',
        :from_state_id => '1',
        :to_state_id => '2',
        :required_roles => ['admin'],
        :guard_conditions => []
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    # This matches the test case that was originally failing
    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      name: 'mixed_test',
      code: 'mixed_code',
      display_name: 'Mixed Test',
      from_state_id: '1',
      to_state_id: '2',
      required_roles: ['admin'],
      workflow_transition: { guard_conditions: [] } # Only guard_conditions nested
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  test "should handle create errors gracefully without parameter mapping issues" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Mock API error response
    WorkflowService.stubs(:create_transition).raises(
      ApiService::ApiError.new("Validation failed")
    )

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        display_name: '', # Empty to trigger validation error
        name: '',
        from_state_id: '1',
        to_state_id: '2'
      }
    }

    assert_response :unprocessable_content
    assert_template :new
    assert_match /Failed to create workflow transition/, flash[:error]

    # Ensure the form can be re-rendered without type conversion errors
    assert_select "input[name='workflow_transition[display_name]']"
    assert_select "select[name='workflow_transition[to_state_id]']"
  end

  test "should handle update errors gracefully without Ruby type errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)
    WorkflowService.stubs(:get_transition).returns(@workflow_transition)

    # Mock API error response
    WorkflowService.stubs(:update_transition).raises(
      ApiService::ApiError.new("Validation failed")
    )

    patch workflow_definition_workflow_transition_url(@workflow_definition['id'], @workflow_transition['id']), params: {
      workflow_transition: {
        display_name: '', # Empty to trigger validation error
        name: ''
      }
    }

    assert_response :unprocessable_content
    assert_template :edit
    assert_match /Failed to update workflow transition/, flash[:error]

    # Ensure the form can be re-rendered without errors
    assert_select "input[name='workflow_transition[display_name]']"
  end

  test "should handle 'Any State' from_state_id conversion correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Test that empty from_state_id maps to nil (Any State)
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :from_state_id => nil,  # Should be nil for "Any State"
        :to_state_id => '2'
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        display_name: 'Test Any State',
        name: 'test_any_state',
        from_state_id: '', # Empty should convert to nil
        to_state_id: '2',
        requires_comment: '0',
        required_roles: [],
        guard_conditions: []
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  test "should handle array parameters correctly" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    # Test that array parameters are processed correctly
    WorkflowService.expects(:create_transition).with(
      @workflow_definition['id'],
      has_entries(
        :required_roles => ['admin', 'manager'],
        :guard_conditions => ['amount > 100', 'status == ready']
      ),
      token: anything
    ).returns(@workflow_transition.merge('id' => 999))

    post workflow_definition_workflow_transitions_url(@workflow_definition['id']), params: {
      workflow_transition: {
        display_name: 'Array Test',
        name: 'array_test',
        from_state_id: '1',
        to_state_id: '2',
        requires_comment: '0',
        required_roles: ['admin', 'manager'],
        guard_conditions: ['amount > 100', 'status == ready']
      }
    }

    assert_redirected_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end
end