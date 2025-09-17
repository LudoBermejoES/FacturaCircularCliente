class WorkflowStatesController < ApplicationController
  before_action :set_workflow_definition
  before_action :set_workflow_state, only: [:show, :edit, :update, :destroy]

  def index
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    result = WorkflowService.definition_states(workflow_id, token: current_user_token)

    # Handle different response formats from API
    if result.is_a?(Hash)
      @workflow_states = result['data'] || result[:data] || result['workflow_states'] || result[:workflow_states] || []
    elsif result.is_a?(Array)
      @workflow_states = result
    else
      @workflow_states = []
    end

    @page_title = "Workflow States - #{@workflow_definition[:name] || @workflow_definition['name']}"
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow states: #{e.message}"
    @workflow_states = []
  end

  def show
    state_name = @workflow_state[:name] || @workflow_state['name']
    @page_title = "#{state_name.capitalize} State"
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow state not found: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_states_path(workflow_id)
  end

  def new
    @workflow_state = WorkflowStateForm.new
    @page_title = "New Workflow State"
  end

  def create
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_state = WorkflowService.create_state(
      workflow_id,
      workflow_state_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow state created successfully'
    state_id = @workflow_state[:id] || @workflow_state['id']
    if state_id
      redirect_to workflow_definition_workflow_state_path(workflow_id, state_id)
    else
      redirect_to workflow_definition_workflow_states_path(workflow_id)
    end
  rescue ApiService::ApiError => e
    @workflow_state = WorkflowStateForm.new(workflow_state_params)
    flash.now[:error] = "Failed to create workflow state: #{e.message}"
    @page_title = "New Workflow State"
    render :new, status: :unprocessable_content
  end

  def edit
    # Convert API hash response to form model for the form
    api_state = @workflow_state
    @original_state = api_state  # Keep original for breadcrumbs and URLs
    @workflow_state = WorkflowStateForm.from_hash(api_state)
    @page_title = "Edit #{api_state['display_name']} State"
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow state not found: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_states_path(workflow_id)
  end

  def update
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    original_state = @workflow_state
    updated_state = WorkflowService.update_state(
      workflow_id,
      original_state['id'],
      workflow_state_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow state updated successfully'
    state_id = updated_state[:id] || updated_state['id']
    if state_id
      redirect_to workflow_definition_workflow_state_path(workflow_id, state_id)
    else
      redirect_to workflow_definition_workflow_states_path(workflow_id)
    end
  rescue ApiService::ApiError => e
    @original_state = original_state  # Preserve original state for URLs and breadcrumbs
    @workflow_state = WorkflowStateForm.new(workflow_state_params)
    flash.now[:error] = "Failed to update workflow state: #{e.message}"
    display_name = (original_state && (original_state['display_name'] || original_state[:display_name])) || 'State'
    @page_title = "Edit #{display_name}"
    render :edit, status: :unprocessable_content
  end

  def destroy
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    state_id = @workflow_state[:id] || @workflow_state['id']
    WorkflowService.delete_state(workflow_id, state_id, token: current_user_token)

    flash[:success] = 'Workflow state deleted successfully'
    redirect_to workflow_definition_workflow_states_path(workflow_id)
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to delete workflow state: #{e.message}"
    redirect_to workflow_definition_workflow_states_path(workflow_id)
  end

  private

  def set_workflow_definition
    @workflow_definition = WorkflowService.definition(params[:workflow_definition_id], token: current_user_token)
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow definition not found: #{e.message}"
    redirect_to workflow_definitions_path
  end

  def set_workflow_state
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_state = WorkflowService.state(
      workflow_id,
      params[:id],
      token: current_user_token
    )
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow state not found: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_states_path(workflow_id)
  end

  def workflow_state_params
    # Handle both nested (:workflow_state) and flat parameter formats
    if params[:workflow_state].present?
      params.require(:workflow_state).permit(
        :name, :code, :category, :color, :position, :is_initial, :is_final, :display_name
      )
    else
      # Handle flat parameters (current form submission format)
      params.permit(
        :name, :code, :category, :color, :position, :is_initial, :is_final, :display_name
      )
    end
  end
end