require "test_helper"

class WorkflowDefinitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_token = "test_token_123"
    @workflow_definition = {
      'id' => 1,
      'name' => 'Standard Invoice Workflow',
      'code' => 'STANDARD_INVOICE',
      'description' => 'Default workflow for invoice processing',
      'company_id' => 1,
      'is_active' => true,
      'is_default' => false
    }
    @states = [
      {
        'id' => 1,
        'name' => 'draft',
        'display_name' => 'Draft',
        'category' => 'draft',
        'color' => '#gray',
        'position' => 1,
        'is_initial' => true
      },
      {
        'id' => 2,
        'name' => 'approved',
        'display_name' => 'Approved',
        'category' => 'approved',
        'color' => '#green',
        'position' => 2,
        'is_final' => true
      }
    ]
    @transitions = [
      {
        'id' => 1,
        'from_state_id' => 1,
        'to_state_id' => 2,
        'name' => 'approve',
        'display_name' => 'Approve',
        'required_roles' => ['manager'],
        'requires_comment' => true
      }
    ]

    # Setup authenticated session using the test helper
    setup_authenticated_session(role: "admin", company_id: 1)
  end

  test "should get index" do
    WorkflowService.stubs(:definitions).returns([@workflow_definition])

    get workflow_definitions_url
    assert_response :success
    assert_not_nil assigns(:workflow_definitions)
    assert_equal 1, assigns(:workflow_definitions).size
  end

  test "should handle API error on index" do
    WorkflowService.stubs(:definitions).raises(ApiService::ApiError.new("API Error"))

    get workflow_definitions_url
    assert_response :success
    assert_equal [], assigns(:workflow_definitions)
    assert_match /Failed to load workflow definitions/, flash[:error]
  end

  test "should get show" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@states)
    WorkflowService.stubs(:definition_transitions).returns(@transitions)

    get workflow_definition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_definition)
    assert_not_nil assigns(:states)
    assert_not_nil assigns(:transitions)
  end

  test "should handle workflow definition with symbol keys" do
    symbolized_definition = {
      id: 1,
      name: 'Symbol Key Workflow',
      code: 'SYMBOL_TEST',
      description: 'Testing symbol key access',
      company_id: 1,
      is_active: true,
      is_default: false
    }
    symbolized_states = [
      {
        id: 1,
        name: 'draft',
        code: 'draft',
        category: 'draft',
        color: '#gray',
        position: 1,
        is_initial: true,
        is_final: false,
        is_error: false
      }
    ]
    symbolized_transitions = [
      {
        id: 1,
        name: 'Submit',
        code: 'submit',
        from_state_id: 1,
        to_state_id: 2,
        required_roles: ['user'],
        required_permissions: []
      }
    ]

    WorkflowService.stubs(:definition).returns(symbolized_definition)
    WorkflowService.stubs(:definition_states).returns(symbolized_states)
    WorkflowService.stubs(:definition_transitions).returns(symbolized_transitions)

    get workflow_definition_url(symbolized_definition[:id])
    assert_response :success
    assert_equal symbolized_definition, assigns(:workflow_definition)
    assert_equal symbolized_states, assigns(:states)
    assert_equal symbolized_transitions, assigns(:transitions)
  end

  test "should handle mixed symbol and string keys" do
    mixed_definition = {
      'id' => 1,
      :name => 'Mixed Keys Workflow',
      'code' => 'MIXED_TEST',
      :description => 'Testing mixed key access',
      'company_id' => 1
    }

    WorkflowService.stubs(:definition).returns(mixed_definition)
    WorkflowService.stubs(:definition_states).returns([])
    WorkflowService.stubs(:definition_transitions).returns([])

    get workflow_definition_url(mixed_definition['id'])
    assert_response :success
    assert_equal mixed_definition, assigns(:workflow_definition)
  end

  test "should redirect on show with invalid id" do
    WorkflowService.stubs(:definition).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_url(999)
    assert_redirected_to workflow_definitions_path
    assert_match /not found/, flash[:error]
  end

  test "should get new" do
    get new_workflow_definition_url
    assert_response :success
    assert_not_nil assigns(:workflow_definition)
  end

  test "should create workflow definition" do
    new_definition = @workflow_definition.merge('id' => 2)
    WorkflowService.stubs(:create_definition).returns(new_definition)

    post workflow_definitions_url, params: {
      workflow_definition: {
        name: 'New Workflow',
        code: 'NEW_WORKFLOW',
        description: 'Test workflow',
        company_id: 1,
        is_active: true,
        is_default: false
      }
    }

    assert_redirected_to workflow_definition_path(new_definition['id'])
    assert_equal 'Workflow definition created successfully', flash[:success]
  end

  test "should override company_id with current user's company on create" do
    new_definition = @workflow_definition.merge('id' => 2, 'company_id' => 1)

    # Mock the service call to verify parameters passed
    create_params = nil
    WorkflowService.stubs(:create_definition).with do |params, options|
      create_params = params
      true
    end.returns(new_definition)

    # User tries to set a different company_id (999) but it should be overridden
    post workflow_definitions_url, params: {
      workflow_definition: {
        name: 'New Workflow',
        code: 'NEW_WORKFLOW',
        description: 'Test workflow',
        company_id: 999,  # This should be ignored
        is_active: true,
        is_default: false
      }
    }

    assert_redirected_to workflow_definition_path(new_definition['id'])
    assert_equal 'Workflow definition created successfully', flash[:success]

    # Verify that the company_id was overridden with current user's company
    assert_equal 1, create_params['company_id'], "Company ID should be overridden to current user's company"
    assert_equal 'New Workflow', create_params['name']
    assert_equal 'NEW_WORKFLOW', create_params['code'], "Code field should be passed through correctly"
  end

  test "should include code field in workflow definition creation" do
    new_definition = @workflow_definition.merge('id' => 3, 'code' => 'TEST_CODE_WF')

    # Mock the service call to verify parameters passed including code
    create_params = nil
    WorkflowService.stubs(:create_definition).with do |params, options|
      create_params = params
      true
    end.returns(new_definition)

    post workflow_definitions_url, params: {
      workflow_definition: {
        name: 'Code Test Workflow',
        code: 'TEST_CODE_WF',
        description: 'Testing code field handling',
        company_id: 1,
        is_active: true,
        is_default: true
      }
    }

    assert_redirected_to workflow_definition_path(new_definition['id'])
    assert_equal 'Workflow definition created successfully', flash[:success]

    # Verify all fields including code are passed correctly
    assert_equal 'Code Test Workflow', create_params['name']
    assert_equal 'TEST_CODE_WF', create_params['code']
    assert_equal 'Testing code field handling', create_params['description']
    assert_equal 1, create_params['company_id']
    # Form checkboxes submit as string values
    assert_not_nil create_params['is_active']
    assert_not_nil create_params['is_default']
  end

  test "should create workflow definition with nil company_id when user has no company" do
    # Set up session with no company
    setup_authenticated_session(role: "admin", company_id: nil)

    new_definition = @workflow_definition.merge('id' => 2, 'company_id' => nil)

    WorkflowService.expects(:create_definition).with do |params, token: nil|
      params['company_id'] == nil && params['name'] == 'New Workflow'
    end.returns(new_definition)

    post workflow_definitions_url, params: {
      workflow_definition: {
        name: 'New Workflow',
        code: 'NEW_WORKFLOW',
        description: 'Test workflow',
        company_id: 999,  # This should be overridden to nil
        is_active: true,
        is_default: false
      }
    }

    assert_redirected_to workflow_definition_path(new_definition['id'])
    assert_equal 'Workflow definition created successfully', flash[:success]
  end

  test "should handle create errors" do
    WorkflowService.stubs(:create_definition).raises(ApiService::ApiError.new("Validation error"))

    post workflow_definitions_url, params: {
      workflow_definition: {
        name: '',
        description: 'Test workflow'
      }
    }

    assert_response :success
    assert_template :new
    assert_match /Failed to create workflow definition/, flash[:error]
  end

  test "should get edit" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    get edit_workflow_definition_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_definition)
  end

  test "should handle edit with symbol keys" do
    symbolized_definition = {
      id: 1,
      name: 'Symbol Edit Test',
      code: 'SYMBOL_EDIT',
      description: 'Testing edit with symbol keys',
      company_id: 1,
      is_active: true,
      is_default: false
    }

    WorkflowService.stubs(:definition).returns(symbolized_definition)

    get edit_workflow_definition_url(symbolized_definition[:id])
    assert_response :success
    assert_equal symbolized_definition, assigns(:workflow_definition)
  end

  test "should update workflow definition" do
    updated_definition = @workflow_definition.merge('name' => 'Updated Workflow')
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:update_definition).returns(updated_definition)

    patch workflow_definition_url(@workflow_definition['id']), params: {
      workflow_definition: {
        name: 'Updated Workflow'
      }
    }

    assert_redirected_to workflow_definition_path(@workflow_definition['id'])
    assert_equal 'Workflow definition updated successfully', flash[:success]
  end

  test "should override company_id with current user's company on update" do
    updated_definition = @workflow_definition.merge('name' => 'Updated Workflow', 'company_id' => 1)
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    # Mock the service call to verify parameters passed
    update_params = nil
    WorkflowService.stubs(:update_definition).with do |id, params, options|
      update_params = params if id == @workflow_definition['id']
      true
    end.returns(updated_definition)

    # User tries to change company_id (999) but it should be overridden
    patch workflow_definition_url(@workflow_definition['id']), params: {
      workflow_definition: {
        name: 'Updated Workflow',
        company_id: 999  # This should be ignored
      }
    }

    assert_redirected_to workflow_definition_path(@workflow_definition['id'])
    assert_equal 'Workflow definition updated successfully', flash[:success]

    # Verify that the company_id was overridden with current user's company
    assert_equal 1, update_params['company_id'], "Company ID should be overridden to current user's company"
    assert_equal 'Updated Workflow', update_params['name']
  end

  test "should update workflow definition with nil company_id when user has no company" do
    # Set up session with no company
    setup_authenticated_session(role: "admin", company_id: nil)

    updated_definition = @workflow_definition.merge('name' => 'Updated Workflow', 'company_id' => nil)
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    WorkflowService.expects(:update_definition).with do |id, params, token: nil|
      id == @workflow_definition['id'] &&
      params['company_id'] == nil &&
      params['name'] == 'Updated Workflow'
    end.returns(updated_definition)

    patch workflow_definition_url(@workflow_definition['id']), params: {
      workflow_definition: {
        name: 'Updated Workflow',
        company_id: 999  # This should be overridden to nil
      }
    }

    assert_redirected_to workflow_definition_path(@workflow_definition['id'])
    assert_equal 'Workflow definition updated successfully', flash[:success]
  end

  test "should handle update errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:update_definition).raises(ApiService::ApiError.new("Validation error"))

    patch workflow_definition_url(@workflow_definition['id']), params: {
      workflow_definition: {
        name: ''
      }
    }

    assert_response :success
    assert_template :edit
    assert_match /Failed to update workflow definition/, flash[:error]
  end

  test "should destroy workflow definition" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:delete_definition).returns(true)

    delete workflow_definition_url(@workflow_definition['id'])

    assert_redirected_to workflow_definitions_path
    assert_equal 'Workflow definition deleted successfully', flash[:success]
  end

  test "should handle destroy errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:delete_definition).raises(ApiService::ApiError.new("Cannot delete"))

    delete workflow_definition_url(@workflow_definition['id'])

    assert_redirected_to workflow_definitions_path
    assert_match /Failed to delete workflow definition/, flash[:error]
  end
end