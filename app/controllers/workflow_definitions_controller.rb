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
    # Use embedded states and transitions from the workflow definition response
    @states = @workflow_definition[:states] || @workflow_definition['states'] || []
    @transitions = @workflow_definition[:transitions] || @workflow_definition['transitions'] || []
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
    Rails.logger.info "DEBUG: create - method started"
    Rails.logger.info "DEBUG: create - params: #{params.inspect}"

    # Override company_id with current user's company to ensure data integrity
    params_with_company = workflow_definition_params.merge(
      company_id: current_company_id
    )

    Rails.logger.info "DEBUG: create - calling WorkflowService.create_definition with params: #{params_with_company.inspect}"
    Rails.logger.info "DEBUG: create - current_user_token: #{current_user_token.present? ? 'present' : 'missing'}"

    begin
      @workflow_definition = WorkflowService.create_definition(
        params_with_company,
        token: current_user_token
      )
      Rails.logger.info "DEBUG: create - success, redirecting with workflow_definition: #{@workflow_definition.inspect}"
      flash[:success] = "Workflow definition created successfully"
      redirect_to workflow_definition_path(@workflow_definition[:id] || @workflow_definition['id'])
    rescue => e
      Rails.logger.info "DEBUG: create - caught exception class: #{e.class.name}"
      Rails.logger.info "DEBUG: create - exception message: #{e.message}"
      Rails.logger.info "DEBUG: create - exception backtrace: #{e.backtrace.first(5).join("\n")}"
      raise
    end
  rescue ApiService::ValidationError => e
    Rails.logger.info "DEBUG: create - caught ValidationError: #{e.message}, errors: #{e.errors}"
    flash.now[:error] = "Failed to create workflow definition"
    if e.errors.is_a?(Hash) && e.errors[:name]
      flash.now[:error] += ": #{e.errors[:name].first}"
    elsif e.errors.is_a?(Hash) && e.errors['name']
      flash.now[:error] += ": #{e.errors['name'].first}"
    else
      flash.now[:error] += ": #{e.message}"
    end
    @workflow_definition = workflow_definition_params
    @page_title = "New Workflow Definition"
    render :new
  rescue ApiService::ApiError => e
    Rails.logger.info "DEBUG: create - caught ApiService::ApiError: #{e.message}"
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
      :name, :code, :description, :company_id, :is_active, :is_default, :company_display
    )
  end
end