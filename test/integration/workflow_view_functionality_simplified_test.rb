require 'test_helper'

class WorkflowViewFunctionalitySimplifiedTest < ActionDispatch::IntegrationTest
  setup do
    # Use the same authentication approach as working system tests
    AuthService.stubs(:login).returns({
      access_token: "test_admin_token",
      refresh_token: "test_refresh_token",
      user: {
        id: 1,
        email: "admin@example.com",
        name: "Admin User",
        company_id: 1
      },
      company_id: 1,
      companies: [{ id: 1, name: "Test Company", role: "admin" }]
    })

    AuthService.stubs(:validate_token).returns({ valid: true })

    # Mock workflow services for simplified testing
    WorkflowService.stubs(:definition).returns({
      id: 1,
      name: "Test Workflow",
      description: "Test workflow"
    })
    WorkflowService.stubs(:definition_states).returns([])
    WorkflowService.stubs(:definition_transitions).returns([])
    WorkflowService.stubs(:definitions).returns({ data: [] })

    # Perform login to establish session
    post login_path, params: {
      email: "admin@example.com",
      password: "password123"
    }
  end

  test "workflow definition page loads successfully" do
    visit workflow_definition_path(1)
    assert_response :success
  end

  test "workflow definitions index loads successfully" do
    get workflow_definitions_path
    assert_response :success
  end

  test "new workflow definition page loads successfully" do
    get new_workflow_definition_path
    assert_response :success
  end

  test "workflow management navigation is accessible" do
    # Test workflow definitions navigation
    get workflow_definitions_path
    assert_response :success

    get new_workflow_definition_path
    assert_response :success

    get workflow_definition_path(1)
    assert_response :success
  end

  private

  def visit(path)
    get path
  end
end