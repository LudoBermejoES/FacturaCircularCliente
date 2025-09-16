require "application_system_test_case"

class WorkflowDefinitionFormsTest < ApplicationSystemTestCase
  setup do
    @company = {
      'id' => 1,
      'name' => 'Test Company Inc.',
      'tax_id' => '12345678Z'
    }

    @workflow_definition = {
      'id' => 1,
      'name' => 'Test Workflow',
      'description' => 'Test workflow description',
      'company_id' => @company['id'],
      'is_active' => true,
      'is_global' => false
    }

    # Setup authenticated session with company
    setup_authenticated_session(
      role: "admin",
      company_id: @company['id'],
      companies: [@company]
    )
  end

  test "new workflow definition form shows current company as read-only" do
    visit new_workflow_definition_path

    assert_text "New Workflow Definition"

    # Check that the company field is present and read-only
    assert_field "Company", with: @company['name'], readonly: true, visible: true

    # Check that the label doesn't say "Optional"
    assert_no_text "Company (Optional)"
    assert_text "Company"

    # Check the help text
    assert_text "Automatically assigned from your current company"

    # Check that the hidden field has the correct company ID
    hidden_field = find("input[name='workflow_definition[company_id]']", visible: false)
    assert_equal @company['id'].to_s, hidden_field.value
  end

  test "edit workflow definition form shows current company as read-only" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    visit edit_workflow_definition_path(@workflow_definition['id'])

    assert_text "Edit Workflow Definition"

    # Check that the company field is present and read-only
    assert_field "Company", with: @company['name'], readonly: true, visible: true

    # Check that the label doesn't say "Optional"
    assert_no_text "Company (Optional)"
    assert_text "Company"

    # Check the help text for edit form
    assert_text "Company assignment is fixed and cannot be changed"

    # Check that the hidden field has the correct company ID
    hidden_field = find("input[name='workflow_definition[company_id]']", visible: false)
    assert_equal @company['id'].to_s, hidden_field.value
  end

  test "new workflow definition form with no company shows appropriate message" do
    # Setup session without company
    setup_authenticated_session(role: "admin", company_id: nil, companies: [])

    visit new_workflow_definition_path

    assert_text "New Workflow Definition"

    # Check that the company field shows no company message
    assert_field "Company", with: "No company assigned", readonly: true, visible: true

    # Check that the hidden field is empty/nil
    hidden_field = find("input[name='workflow_definition[company_id]']", visible: false)
    assert_equal "", hidden_field.value
  end

  test "can create workflow definition with company automatically assigned" do
    # Mock the service response
    new_workflow = @workflow_definition.merge('id' => 2, 'name' => 'New Test Workflow')
    WorkflowService.stubs(:create_definition).returns(new_workflow)

    visit new_workflow_definition_path

    # Fill in the form
    fill_in "Name", with: "New Test Workflow"
    fill_in "Description", with: "A new test workflow description"
    check "Active"

    # Submit the form
    click_button "Create Workflow Definition"

    # Should redirect to the show page
    assert_text "Workflow definition created successfully"
    assert_current_path workflow_definition_path(new_workflow['id'])
  end

  test "can update workflow definition with company field unchanged" do
    WorkflowService.stubs(:definition).returns(@workflow_definition)

    updated_workflow = @workflow_definition.merge('name' => 'Updated Test Workflow')
    WorkflowService.stubs(:update_definition).returns(updated_workflow)

    visit edit_workflow_definition_path(@workflow_definition['id'])

    # Update the form
    fill_in "Name", with: "Updated Test Workflow"

    # Verify company field is still read-only and unchanged
    assert_field "Company", with: @company['name'], readonly: true

    # Submit the form
    click_button "Update Workflow Definition"

    # Should redirect to the show page
    assert_text "Workflow definition updated successfully"
    assert_current_path workflow_definition_path(@workflow_definition['id'])
  end

  test "form fields are properly styled and accessible" do
    visit new_workflow_definition_path

    # Check form styling classes
    company_field = find("input[readonly]")
    assert company_field[:class].include?("bg-gray-50")
    assert company_field[:class].include?("text-gray-700")
    assert company_field[:class].include?("rounded-md")

    # Check that the field is properly labeled
    label = find("label", text: "Company")
    assert_equal "block text-sm font-medium text-gray-700", label[:class]

    # Check accessibility attributes
    assert company_field[:readonly]
  end

  test "company field handles different company name formats" do
    # Test with company that has symbols/special characters
    special_company = {
      'id' => 2,
      'name' => 'Acme Corp. & Co. (España)',
      'tax_id' => 'ESB12345678'
    }

    setup_authenticated_session(
      role: "admin",
      company_id: special_company['id'],
      companies: [special_company]
    )

    visit new_workflow_definition_path

    # Should properly display the company name with special characters
    assert_field "Company", with: special_company['name'], readonly: true
  end

  test "form validation works correctly with automatic company assignment" do
    # Mock service to raise validation error
    WorkflowService.stubs(:create_definition)
      .raises(ApiService::ApiError.new("Name can't be blank"))

    visit new_workflow_definition_path

    # Leave name blank and submit
    fill_in "Name", with: ""
    fill_in "Description", with: "Test description"

    click_button "Create Workflow Definition"

    # Should stay on the same page and show error
    assert_text "Failed to create workflow definition"
    assert_text "Name can't be blank"
    assert_current_path workflow_definitions_path

    # Company field should still be properly set
    assert_field "Company", with: @company['name'], readonly: true
  end

  private

  def setup_authenticated_session(role: "admin", company_id: 1, companies: [])
    # Mock authentication methods
    ApplicationController.any_instance.stubs(:authenticate_user!).returns(true)
    ApplicationController.any_instance.stubs(:current_user_token).returns("test_token")
    ApplicationController.any_instance.stubs(:current_company_id).returns(company_id)

    if company_id && companies.any?
      current_company = companies.find { |c| c['id'] == company_id }
      ApplicationController.any_instance.stubs(:current_company).returns(current_company)
    else
      ApplicationController.any_instance.stubs(:current_company).returns(nil)
    end

    ApplicationController.any_instance.stubs(:user_companies).returns(companies)
    ApplicationController.any_instance.stubs(:current_user_role).returns(role)
    ApplicationController.any_instance.stubs(:can?).returns(true)
  end
end