require "test_helper"

class WorkflowStatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workflow_definition = {
      'id' => 1,
      'name' => 'Standard Invoice Workflow',
      'description' => 'Default workflow for invoice processing',
      'company_id' => 1,
      'is_active' => true,
      'is_global' => false
    }

    @workflow_state = {
      'id' => 1,
      'name' => 'draft',
      'display_name' => 'Draft',
      'category' => 'draft',
      'color' => '#gray',
      'position' => 1,
      'is_initial' => true,
      'is_final' => false
    }

    @workflow_states = [
      @workflow_state,
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

    # Setup authenticated session using the test helper
    setup_authenticated_session(role: "admin", company_id: 1)
  end

  test "should get index" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).returns(@workflow_states)

    get workflow_definition_workflow_states_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_states)
    assert_not_nil assigns(:workflow_definition)
  end


  test "should handle API error on index" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:definition_states).raises(ApiService::ApiError.new("API Error"))

    get workflow_definition_workflow_states_url(@workflow_definition['id'])
    assert_response :success
    assert_equal [], assigns(:workflow_states)
    assert_match /Failed to load workflow states/, flash[:error]
  end

  test "should redirect if workflow definition not found" do
    WorkflowService.stubs(:definition).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_workflow_states_url(999)
    assert_redirected_to workflow_definitions_path
    assert_match /Workflow definition not found/, flash[:error]
  end

  test "should get show" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)

    get workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_state)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should redirect on show with invalid state id" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_workflow_state_url(@workflow_definition['id'], 999)
    assert_redirected_to workflow_definition_workflow_states_path(@workflow_definition['id'])
    assert_match /Workflow state not found/, flash[:error]
  end

  test "should get new" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    get new_workflow_definition_workflow_state_url(@workflow_definition['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_state)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should create workflow state" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    new_state = @workflow_state.merge('id' => 3, 'name' => 'pending')
    WorkflowService.stubs(:create_state).returns(new_state)

    post workflow_definition_workflow_states_url(@workflow_definition['id']), params: {
      workflow_state: {
        name: 'pending',
        display_name: 'Pending Review',
        category: 'review',
        color: '#orange',
        position: 3,
        is_initial: false,
        is_final: false
      }
    }

    assert_redirected_to workflow_definition_workflow_state_path(@workflow_definition['id'], new_state['id'])
    assert_equal 'Workflow state created successfully', flash[:success]
  end

  test "should handle create errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:create_state).raises(ApiService::ApiError.new("Validation error"))

    post workflow_definition_workflow_states_url(@workflow_definition['id']), params: {
      workflow_state: {
        name: '',
        display_name: ''
      }
    }

    assert_response :unprocessable_content
    assert_template :new
    assert_match /Failed to create workflow state/, flash[:error]
  end

  test "should get edit" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)

    get edit_workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id'])
    assert_response :success
    assert_not_nil assigns(:workflow_state)
    assert_not_nil assigns(:workflow_definition)
  end

  test "should update workflow state" do
    updated_state = @workflow_state.merge('display_name' => 'Updated Draft')
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)
    WorkflowService.stubs(:update_state).returns(updated_state)

    patch workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id']), params: {
      workflow_state: {
        display_name: 'Updated Draft'
      }
    }

    assert_redirected_to workflow_definition_workflow_state_path(@workflow_definition['id'], @workflow_state['id'])
    assert_equal 'Workflow state updated successfully', flash[:success]
  end

  test "should handle update errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)
    WorkflowService.stubs(:update_state).raises(ApiService::ApiError.new("Validation error"))

    patch workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id']), params: {
      workflow_state: {
        name: ''
      }
    }

    assert_response :unprocessable_content
    assert_template :edit
    assert_match /Failed to update workflow state/, flash[:error]
  end

  test "should destroy workflow state" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)
    WorkflowService.stubs(:delete_state).returns(true)

    delete workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id'])

    assert_redirected_to workflow_definition_workflow_states_path(@workflow_definition['id'])
    assert_equal 'Workflow state deleted successfully', flash[:success]
  end

  test "should handle destroy errors" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.stubs(:state).returns(@workflow_state)
    WorkflowService.stubs(:delete_state).raises(ApiService::ApiError.new("Cannot delete"))

    delete workflow_definition_workflow_state_url(@workflow_definition['id'], @workflow_state['id'])

    assert_redirected_to workflow_definition_workflow_states_path(@workflow_definition['id'])
    assert_match /Failed to delete workflow state/, flash[:error]
  end

  test "should handle workflow definition not found in before_action" do
    WorkflowService.stubs(:definition).raises(ApiService::ApiError.new("Not found"))

    get workflow_definition_workflow_states_url(999)
    assert_redirected_to workflow_definitions_path
    assert_match /Workflow definition not found/, flash[:error]
  end

  test "workflow state params filtering" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)
    WorkflowService.expects(:create_state).with(
      @workflow_definition['id'],
      has_entries('name' => 'test', 'display_name' => 'Test', 'color' => '#ff0000'),
      token: anything
    ).returns(@workflow_state.merge('id' => 999))

    post workflow_definition_workflow_states_url(@workflow_definition['id']), params: {
      workflow_state: {
        name: 'test',
        display_name: 'Test',
        category: 'test',
        color: '#ff0000',
        position: 1,
        is_initial: true,
        is_final: false,
        # These should be filtered out
        invalid_param: 'should_be_ignored',
        id: 'should_be_ignored'
      }
    }

    assert_redirected_to workflow_definition_workflow_state_path(@workflow_definition['id'], 999)
  end
end