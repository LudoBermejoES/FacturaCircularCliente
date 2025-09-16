require "test_helper"

class WorkflowDefinitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_token = "test_token_123"
    @workflow_definition = {
      'id' => 1,
      'name' => 'Standard Invoice Workflow',
      'description' => 'Default workflow for invoice processing',
      'company_id' => 1,
      'is_active' => true,
      'is_global' => false
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
        description: 'Test workflow',
        company_id: 1,
        is_active: true,
        is_global: false
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