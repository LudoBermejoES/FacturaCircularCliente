class WorkflowDefinitionsController < ApplicationController
  before_action :set_workflow_definition, only: [:show, :edit, :update, :destroy]

  def index
    result = WorkflowService.definitions(token: current_user_token)
    Rails.logger.info "DEBUG: WorkflowDefinitionsController#index - raw result: #{result.inspect}"
    Rails.logger.info "DEBUG: WorkflowDefinitionsController#index - result class: #{result.class}"

    # Handle different response formats
    if result.is_a?(Hash)
      # API might return { "workflow_definitions": [...] } or { "data": [...] } or with symbol keys
      @workflow_definitions = result['workflow_definitions'] || result[:workflow_definitions] ||
                             result['data'] || result[:data] || []
      Rails.logger.info "DEBUG: Extracted from hash - definitions: #{@workflow_definitions.inspect}"
    elsif result.is_a?(Array)
      @workflow_definitions = result
    else
      Rails.logger.warn "DEBUG: Unexpected result type: #{result.class}"
      @workflow_definitions = []
    end

    @page_title = "Workflow Definitions"
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to load workflow definitions: #{e.message}"
    @workflow_definitions = []
  end

  def show
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @states = WorkflowService.definition_states(
      workflow_id,
      token: current_user_token
    )
    @transitions = WorkflowService.definition_transitions(
      workflow_id,
      token: current_user_token
    )
    @page_title = @workflow_definition[:name] || @workflow_definition['name']
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow details: #{e.message}"
    redirect_to workflow_definitions_path
  end

  def new
    @workflow_definition = {}
    @page_title = "New Workflow Definition"
  end

  def create
    # Override company_id with current user's company to ensure data integrity
    params_with_company = workflow_definition_params.merge(
      company_id: current_company_id
    )

    @workflow_definition = WorkflowService.create_definition(
      params_with_company,
      token: current_user_token
    )
    flash[:success] = "Workflow definition created successfully"
    redirect_to workflow_definition_path(@workflow_definition[:id] || @workflow_definition['id'])
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to create workflow definition: #{e.message}"
    @workflow_definition = workflow_definition_params
    @page_title = "New Workflow Definition"
    render :new
  end

  def edit
    @page_title = "Edit #{@workflow_definition[:name] || @workflow_definition['name']}"
  end

  def update
    # Override company_id with current user's company to ensure data integrity
    params_with_company = workflow_definition_params.merge(
      company_id: current_company_id
    )

    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    @workflow_definition = WorkflowService.update_definition(
      workflow_id,
      params_with_company,
      token: current_user_token
    )
    flash[:success] = "Workflow definition updated successfully"
    redirect_to workflow_definition_path(@workflow_definition[:id] || @workflow_definition['id'])
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to update workflow definition: #{e.message}"
    @page_title = "Edit #{@workflow_definition[:name] || @workflow_definition['name']}"
    render :edit
  end

  def destroy
    workflow_id = @workflow_definition[:id] || @workflow_definition['id']
    WorkflowService.delete_definition(workflow_id, token: current_user_token)
    flash[:success] = "Workflow definition deleted successfully"
    redirect_to workflow_definitions_path
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to delete workflow definition: #{e.message}"
    redirect_to workflow_definitions_path
  end

  private

  def set_workflow_definition
    @workflow_definition = WorkflowService.definition(params[:id], token: current_user_token)
    Rails.logger.info "DEBUG: set_workflow_definition - raw result: #{@workflow_definition.inspect}"
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow definition not found"
    redirect_to workflow_definitions_path
  end

  def workflow_definition_params
    # Note: company_display is ignored as it's just for display
    params.require(:workflow_definition).permit(
      :name, :code, :description, :company_id, :is_active, :is_default
    )
  end
end