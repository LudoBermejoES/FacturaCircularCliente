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

    # Ensure workflow_id is present
    if workflow_id.blank?
      flash.now[:error] = "Workflow definition ID is missing"
      @workflow_state = WorkflowStateForm.new(workflow_state_params)
      @page_title = "New Workflow State"
      render :new, status: :unprocessable_content
      return
    end

    result = WorkflowService.create_state(
      workflow_id,
      workflow_state_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow state created successfully'

    # Handle API response format - could be nested under 'data' or direct
    state_data = result.is_a?(Hash) && result['data'] ? result['data'] : result
    state_id = state_data[:id] || state_data['id'] if state_data.is_a?(Hash)

    # Always redirect to index page if state_id is missing
    redirect_to workflow_definition_workflow_states_path(workflow_id)
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

    # Ensure workflow_id is present
    if workflow_id.blank?
      @original_state = original_state
      @workflow_state = WorkflowStateForm.new(workflow_state_params)
      flash.now[:error] = "Workflow definition ID is missing"
      @page_title = "Edit State"
      render :edit, status: :unprocessable_content
      return
    end

    # Extract state ID from API response (handle both string and symbol keys)
    state_id = original_state[:id] || original_state['id']
    Rails.logger.info "DEBUG: update - original_state: #{original_state.inspect}"
    Rails.logger.info "DEBUG: update - extracted state_id: #{state_id.inspect}"

    if state_id.blank?
      flash.now[:error] = "Workflow state ID is missing"
      @original_state = original_state
      @workflow_state = WorkflowStateForm.new(workflow_state_params)
      @page_title = "Edit State"
      render :edit, status: :unprocessable_content
      return
    end

    result = WorkflowService.update_state(
      workflow_id,
      state_id,
      workflow_state_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow state updated successfully'

    # Always redirect to index page
    redirect_to workflow_definition_workflow_states_path(workflow_id)
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
    permitted = if params[:workflow_state].present?
      params.require(:workflow_state).permit(
        :name, :code, :category, :color, :position, :is_initial, :is_final, :display_name, :description
      )
    else
      # Handle flat parameters (current form submission format)
      # Convert flat params to expected API format
      {
        name: params[:name],
        code: params[:code],
        category: params[:category],
        description: params[:description],
        color: params[:color],
        position: params[:position].to_i,
        is_initial: params[:is_initial] == '1',
        is_final: params[:is_final] == '1'
      }.compact
    end

    # Convert to hash if ActionController::Parameters
    permitted = permitted.to_h if permitted.respond_to?(:to_h)

    # Map form fields to API fields
    if permitted[:name].present? && permitted[:display_name].blank?
      permitted[:display_name] = permitted[:name]
    end

    # Ensure position is a positive integer
    if permitted[:position].blank? || permitted[:position].to_i <= 0
      permitted[:position] = 1
    else
      permitted[:position] = permitted[:position].to_i
    end

    # Ensure code is present - generate from name if missing
    if permitted[:code].blank? && permitted[:name].present?
      permitted[:code] = permitted[:name].to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
    end

    permitted
  end
end