class UserCompaniesController < ApplicationController
  before_action :ensure_company_selected
  before_action :ensure_admin_or_owner
  before_action :set_user, only: [:edit, :update, :destroy]
  
  # GET /companies/:company_id/users
  def index
    @company = current_company
    @users = fetch_company_users
  end
  
  # GET /companies/:company_id/users/new
  def new
    @company = current_company
    @available_roles = available_roles_for_current_user
  end
  
  # POST /companies/:company_id/users
  def create
    begin
      response = UserCompanyService.invite_user(
        company_id: current_company_id,
        email: params[:email],
        role: params[:role],
        token: current_token
      )
      
      redirect_to company_users_path(current_company_id), 
                  notice: "User #{params[:email]} has been invited to #{current_company['name']}."
    rescue ApiService::ValidationError => e
      @company = current_company
      @available_roles = available_roles_for_current_user
      @errors = e.errors
      flash.now[:alert] = 'There were errors inviting the user.'
      render :new, status: :unprocessable_content
    rescue ApiService::ApiError => e
      redirect_to company_users_path(current_company_id), 
                  alert: "Error inviting user: #{e.message}"
    end
  end
  
  # GET /companies/:company_id/users/:id/edit
  def edit
    @company = current_company
    @available_roles = available_roles_for_current_user
  end
  
  # PATCH /companies/:company_id/users/:id
  def update
    begin
      response = UserCompanyService.update_user_role(
        company_id: current_company_id,
        user_id: params[:id],
        role: params[:role],
        token: current_token
      )
      
      redirect_to company_users_path(current_company_id), 
                  notice: "User role has been updated."
    rescue ApiService::ValidationError => e
      @company = current_company
      @available_roles = available_roles_for_current_user
      @errors = e.errors
      flash.now[:alert] = 'There were errors updating the user role.'
      render :edit, status: :unprocessable_content
    rescue ApiService::ApiError => e
      redirect_to company_users_path(current_company_id), 
                  alert: "Error updating user: #{e.message}"
    end
  end
  
  # DELETE /companies/:company_id/users/:id
  def destroy
    begin
      response = UserCompanyService.remove_user(
        company_id: current_company_id,
        user_id: params[:id],
        token: current_token
      )
      
      redirect_to company_users_path(current_company_id), 
                  notice: "User has been removed from #{current_company['name']}."
    rescue ApiService::ApiError => e
      redirect_to company_users_path(current_company_id), 
                  alert: "Error removing user: #{e.message}"
    end
  end
  
  private
  
  def ensure_company_selected
    unless current_company_id
      redirect_to select_company_path, alert: 'Please select a company first.'
    end
  end
  
  def ensure_admin_or_owner
    user_role = current_user_role_in_company
    unless %w[owner admin manager].include?(user_role)
      redirect_to dashboard_path, alert: 'You do not have permission to manage users.'
    end
  end
  
  def current_user_role_in_company
    return nil unless current_company_id && user_companies.present?
    
    company = user_companies.find { |c| (c['id'] || c[:id]) == current_company_id }
    company ? (company['role'] || company[:role]) : nil
  end
  
  def set_user
    @user = fetch_company_users.find { |u| u[:id].to_s == params[:id] }
    unless @user
      redirect_to company_users_path(current_company_id), alert: 'User not found.'
    end
  end
  
  def fetch_company_users
    UserCompanyService.list_users(
      company_id: current_company_id,
      token: current_token
    )
  rescue ApiService::ApiError => e
    Rails.logger.error "Failed to fetch company users: #{e.message}"
    []
  end
  
  def available_roles_for_current_user
    user_role = current_user_role_in_company
    
    case user_role
    when 'owner'
      %w[owner admin manager accountant reviewer submitter viewer]
    when 'admin'
      %w[manager accountant reviewer submitter viewer]
    when 'manager'
      %w[accountant reviewer submitter viewer]
    else
      []
    end
  end
end