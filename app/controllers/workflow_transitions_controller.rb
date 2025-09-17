class WorkflowTransitionsController < ApplicationController
  before_action :set_workflow_definition
  before_action :set_workflow_transition, only: [:show, :edit, :update, :destroy]

  def index
    @workflow_transitions = WorkflowService.definition_transitions(@workflow_definition['id'], token: current_user_token)
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    @page_title = "Workflow Transitions - #{@workflow_definition['name']}"
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow transitions: #{e.message}"
    @workflow_transitions = []
    @workflow_states = []
  end

  def show
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    @from_state = @workflow_states.find { |state| state['id'] == @workflow_transition['from_state_id'] }
    @to_state = @workflow_states.find { |state| state['id'] == @workflow_transition['to_state_id'] }
    @page_title = "#{@workflow_transition['display_name']} Transition"
  end

  def new
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    @workflow_transition = {
      'name' => '',
      'display_name' => '',
      'from_state_id' => '',
      'to_state_id' => '',
      'required_roles' => [],
      'requires_comment' => false,
      'guard_conditions' => []
    }
    @page_title = "New Workflow Transition"
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow states: #{e.message}"
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  def create
    @workflow_transition = WorkflowService.create_transition(
      @workflow_definition['id'],
      workflow_transition_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow transition created successfully'
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  rescue ApiService::ApiError => e
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    @workflow_transition = workflow_transition_params.merge({
      'name' => workflow_transition_params[:name] || '',
      'display_name' => workflow_transition_params[:display_name] || '',
      'from_state_id' => workflow_transition_params[:from_state_id] || '',
      'to_state_id' => workflow_transition_params[:to_state_id] || '',
      'required_roles' => workflow_transition_params[:required_roles] || [],
      'requires_comment' => workflow_transition_params[:requires_comment] || false,
      'guard_conditions' => workflow_transition_params[:guard_conditions] || []
    })
    flash.now[:error] = "Failed to create workflow transition: #{e.message}"
    @page_title = "New Workflow Transition"
    render :new, status: :unprocessable_content
  end

  def edit
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    @page_title = "Edit #{@workflow_transition['display_name']} Transition"
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow transition not found: #{e.message}"
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  def update
    @workflow_transition = WorkflowService.update_transition(
      @workflow_definition['id'],
      @workflow_transition['id'],
      workflow_transition_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow transition updated successfully'
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  rescue ApiService::ApiError => e
    @workflow_states = WorkflowService.definition_states(@workflow_definition['id'], token: current_user_token)
    flash.now[:error] = "Failed to update workflow transition: #{e.message}"
    @page_title = "Edit #{@workflow_transition['display_name']} Transition"
    render :edit, status: :unprocessable_content
  end

  def destroy
    WorkflowService.delete_transition(
      @workflow_definition['id'],
      @workflow_transition['id'],
      token: current_user_token
    )

    flash[:success] = 'Workflow transition deleted successfully'
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to delete workflow transition: #{e.message}"
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  private

  def set_workflow_definition
    @workflow_definition = WorkflowService.definition(params[:workflow_definition_id], token: current_user_token)
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow definition not found: #{e.message}"
    redirect_to workflow_definitions_path
  end

  def set_workflow_transition
    @workflow_transition = WorkflowService.get_transition(
      @workflow_definition['id'],
      params[:id],
      token: current_user_token
    )
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow transition not found: #{e.message}"
    redirect_to workflow_definition_workflow_transitions_path(@workflow_definition['id'])
  end

  def workflow_transition_params
    permitted = params.require(:workflow_transition).permit(
      :name, :display_name, :from_state_id, :to_state_id, :requires_comment,
      required_roles: [], guard_conditions: []
    )

    # Convert empty strings to nil for state IDs
    permitted[:from_state_id] = nil if permitted[:from_state_id].blank?
    permitted[:to_state_id] = nil if permitted[:to_state_id].blank?

    # Ensure required_roles is an array and filter empty strings
    permitted[:required_roles] = Array(permitted[:required_roles]).reject(&:blank?)

    # Ensure guard_conditions is an array and filter empty strings
    permitted[:guard_conditions] = Array(permitted[:guard_conditions]).reject(&:blank?)

    permitted
  end
end