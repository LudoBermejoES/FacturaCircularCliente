class WorkflowTransitionsController < ApplicationController
  before_action :set_workflow_definition
  before_action :set_workflow_transition, only: [:show, :edit, :update, :destroy]

  def index
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    transitions_result = WorkflowService.definition_transitions(workflow_id, token: current_user_token)
    states_result = WorkflowService.definition_states(workflow_id, token: current_user_token)

    # Handle different response formats from API for transitions
    if transitions_result.is_a?(Hash)
      @workflow_transitions = transitions_result['data'] || transitions_result[:data] || transitions_result['workflow_transitions'] || transitions_result[:workflow_transitions] || []
    elsif transitions_result.is_a?(Array)
      @workflow_transitions = transitions_result
    else
      @workflow_transitions = []
    end

    # Handle different response formats from API for states
    if states_result.is_a?(Hash)
      @workflow_states = states_result['data'] || states_result[:data] || states_result['workflow_states'] || states_result[:workflow_states] || []
    elsif states_result.is_a?(Array)
      @workflow_states = states_result
    else
      @workflow_states = []
    end

    @page_title = "Workflow Transitions - #{@workflow_definition[:name] || @workflow_definition['name']}"
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow transitions: #{e.message}"
    @workflow_transitions = []
    @workflow_states = []
  end

  def show
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

    @from_state = @workflow_states.find { |state| (state[:code] || state['code']) == (@workflow_transition[:from_state_code] || @workflow_transition['from_state_code']) }
    @to_state = @workflow_states.find { |state| (state[:code] || state['code']) == (@workflow_transition[:to_state_code] || @workflow_transition['to_state_code']) }
    @page_title = "#{@workflow_transition[:display_name] || @workflow_transition['display_name']} Transition"
  end

  def new
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

    @workflow_transition = {
      'name' => '',
      'code' => '',
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
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  end

  def create
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_transition = WorkflowService.create_transition(
      workflow_id,
      workflow_transition_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow transition created successfully'
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  rescue ApiService::ApiError => e
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']

    # Load workflow states for the form
    begin
      states_result = WorkflowService.definition_states(workflow_id, token: current_user_token)
      if states_result.is_a?(Hash)
        @workflow_states = states_result['data'] || states_result[:data] || []
      elsif states_result.is_a?(Array)
        @workflow_states = states_result
      else
        @workflow_states = []
      end
    rescue ApiService::ApiError
      @workflow_states = []
    end

    # Build transition hash from submitted parameters
    transition_params = workflow_transition_params
    @workflow_transition = {
      'name' => transition_params[:name] || '',
      'code' => transition_params[:code] || '',
      'display_name' => transition_params[:display_name] || '',
      'from_state_id' => transition_params[:from_state_id] || '',
      'to_state_id' => transition_params[:to_state_id] || '',
      'required_roles' => transition_params[:required_roles] || [],
      'requires_comment' => transition_params[:requires_comment] || false,
      'guard_conditions' => transition_params[:guard_conditions] || []
    }

    flash.now[:error] = "Failed to create workflow transition: #{e.message}"
    @page_title = "New Workflow Transition"
    render :new, status: :unprocessable_content
  end

  def edit
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

    @page_title = "Edit #{@workflow_transition[:display_name] || @workflow_transition['display_name']} Transition"
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow transition not found: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  end

  def update
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_transition = WorkflowService.update_transition(
      workflow_id,
      @workflow_transition[:id] || @workflow_transition['id'],
      workflow_transition_params,
      token: current_user_token
    )

    flash[:success] = 'Workflow transition updated successfully'
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  rescue ApiService::ApiError => e
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

    flash.now[:error] = "Failed to update workflow transition: #{e.message}"
    @page_title = "Edit #{@workflow_transition[:display_name] || @workflow_transition['display_name']} Transition"
    render :edit, status: :unprocessable_content
  end

  def destroy
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    WorkflowService.delete_transition(
      workflow_id,
      @workflow_transition[:id] || @workflow_transition['id'],
      token: current_user_token
    )

    flash[:success] = 'Workflow transition deleted successfully'
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to delete workflow transition: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  end

  private

  def set_workflow_definition
    @workflow_definition = WorkflowService.definition(params[:workflow_definition_id], token: current_user_token)
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow definition not found: #{e.message}"
    redirect_to workflow_definitions_path
  end

  def set_workflow_transition
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_transition = WorkflowService.get_transition(
      workflow_id,
      params[:id],
      token: current_user_token
    )
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow transition not found: #{e.message}"
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    redirect_to workflow_definition_workflow_transitions_path(workflow_id)
  end

  def workflow_transition_params
    # Handle both nested (:workflow_transition) and flat parameter formats
    # Check if workflow_transition contains the main form fields (not just guard_conditions)
    permitted = if params[:workflow_transition].present? &&
                   (params[:workflow_transition].key?(:display_name) || params[:workflow_transition].key?('display_name') ||
                    params[:workflow_transition].key?(:name) || params[:workflow_transition].key?('name'))
      # Standard form submission with nested parameters
      params.require(:workflow_transition).permit(
        :name, :code, :display_name, :from_state_id, :to_state_id, :requires_comment,
        required_roles: [], guard_conditions: []
      )
    else
      # Handle flat parameters or mixed format (including when workflow_transition only has certain keys)
      nested_params = params[:workflow_transition] || {}
      {
        name: params[:name],
        display_name: params[:display_name],
        code: params[:code],
        from_state_id: params[:from_state_id],
        to_state_id: params[:to_state_id],
        requires_comment: params[:requires_comment] == '1',
        required_roles: params[:required_roles] || [],
        guard_conditions: nested_params[:guard_conditions] || params[:guard_conditions] || []
      }
    end

    # Convert to hash if ActionController::Parameters
    permitted = permitted.to_h if permitted.respond_to?(:to_h)

    # Ensure name is present - use display_name if missing
    if permitted[:name].blank? && permitted[:display_name].present?
      permitted[:name] = permitted[:display_name]
    end

    # Ensure code is present - generate from name if missing
    if permitted[:code].blank? && permitted[:name].present?
      permitted[:code] = permitted[:name].to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
    end

    # Handle state IDs properly - convert empty strings to nil for from_state, but keep to_state as required
    if permitted[:from_state_id].blank? || permitted[:from_state_id] == 'any'
      permitted[:from_state_id] = nil
    end

    # For to_state_id, convert empty to nil but this will be caught by API validation
    if permitted[:to_state_id].blank?
      permitted[:to_state_id] = nil
    end

    # Handle arrays - ensure they're arrays and remove blanks
    [:required_roles, :guard_conditions].each do |key|
      value = permitted[key]
      if value.is_a?(Array)
        permitted[key] = value.reject(&:blank?)
      elsif value.is_a?(String)
        permitted[key] = value.split(',').map(&:strip).reject(&:blank?)
      else
        permitted[key] = []
      end
    end

    # Remove nil values except for from_state_id which can be nil
    permitted.compact.merge(
      permitted[:from_state_id].nil? ? { from_state_id: nil } : {}
    )
  end

  private

  def parse_array_param(param)
    case param
    when Array then param.reject(&:blank?)
    when ActionController::Parameters then param.to_a.reject(&:blank?)
    when String then param.split(',').map(&:strip).reject(&:blank?)
    else []
    end
  end

  def parse_json_param(param)
    case param
    when Hash then param
    when Array then param
    when String
      return {} if param.blank?
      begin
        JSON.parse(param)
      rescue JSON::ParserError
        {}
      end
    else
      param.respond_to?(:empty?) && param.empty? ? [] : {}
    end
  end
end