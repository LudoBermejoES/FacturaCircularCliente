class WorkflowDefinitionsController < ApplicationController
  before_action :require_authentication
  before_action :set_workflow_definition, only: [:show, :edit, :update, :destroy]

  def index
    @workflow_definitions = WorkflowService.definitions(token: current_user_token)
    @page_title = "Workflow Definitions"
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to load workflow definitions: #{e.message}"
    @workflow_definitions = []
  end

  def show
    @states = WorkflowService.definition_states(
      @workflow_definition['id'],
      token: current_user_token
    )
    @transitions = WorkflowService.definition_transitions(
      @workflow_definition['id'],
      token: current_user_token
    )
    @page_title = @workflow_definition['name']
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to load workflow details: #{e.message}"
    redirect_to workflow_definitions_path
  end

  def new
    @workflow_definition = {}
    @page_title = "New Workflow Definition"
  end

  def create
    @workflow_definition = WorkflowService.create_definition(
      workflow_definition_params,
      token: current_user_token
    )
    flash[:success] = "Workflow definition created successfully"
    redirect_to workflow_definition_path(@workflow_definition['id'])
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to create workflow definition: #{e.message}"
    @workflow_definition = workflow_definition_params
    @page_title = "New Workflow Definition"
    render :new
  end

  def edit
    @page_title = "Edit #{@workflow_definition['name']}"
  end

  def update
    @workflow_definition = WorkflowService.update_definition(
      @workflow_definition['id'],
      workflow_definition_params,
      token: current_user_token
    )
    flash[:success] = "Workflow definition updated successfully"
    redirect_to workflow_definition_path(@workflow_definition['id'])
  rescue ApiService::ApiError => e
    flash.now[:error] = "Failed to update workflow definition: #{e.message}"
    @page_title = "Edit #{@workflow_definition['name']}"
    render :edit
  end

  def destroy
    WorkflowService.delete_definition(@workflow_definition['id'], token: current_user_token)
    flash[:success] = "Workflow definition deleted successfully"
    redirect_to workflow_definitions_path
  rescue ApiService::ApiError => e
    flash[:error] = "Failed to delete workflow definition: #{e.message}"
    redirect_to workflow_definitions_path
  end

  private

  def set_workflow_definition
    @workflow_definition = WorkflowService.definition(params[:id], token: current_user_token)
  rescue ApiService::ApiError => e
    flash[:error] = "Workflow definition not found"
    redirect_to workflow_definitions_path
  end

  def workflow_definition_params
    params.require(:workflow_definition).permit(
      :name, :description, :company_id, :is_active, :is_global
    )
  end
end