class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  skip_before_action :debug_request
  
  def new
    Rails.logger.info "DEBUG: SessionsController#new called"
    if logged_in?
      Rails.logger.info "DEBUG: User already logged in, redirecting to dashboard"
      redirect_to dashboard_path
    end
  rescue => e
    Rails.logger.error "DEBUG: SessionsController#new error: #{e.message}"
    Rails.logger.error "DEBUG: SessionsController#new backtrace: #{e.backtrace.first(10).join('\n')}"
    raise e
  end
  
  def create
    Rails.logger.info "DEBUG: SessionsController#create - CSRF bypassed successfully!"
    Rails.logger.info "DEBUG: Params: #{params.except(:password).inspect}"
    
    auth_response = AuthService.login(
      params[:email],
      params[:password]
    )
    
    Rails.logger.info "DEBUG: AuthService returned: #{auth_response ? 'SUCCESS' : 'FAILURE'}"
    
    if auth_response
      store_session(auth_response)
      redirect_to dashboard_path, notice: 'Successfully logged in!'
    else
      flash.now[:alert] = 'Invalid email or password'
      render :new, status: :unprocessable_entity
    end
  rescue ApiService::AuthenticationError => e
    Rails.logger.error "DEBUG: Authentication error in create: #{e.message}"
    flash.now[:alert] = 'Invalid credentials'
    render :new, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "DEBUG: Exception in create: #{e.message}"
    Rails.logger.error "DEBUG: Backtrace: #{e.backtrace.first(3).join('\n')}"
    raise e
  end
  
  def destroy
    begin
      AuthService.logout(current_token) if current_token
    rescue => e
      Rails.logger.error "Logout error: #{e.message}"
    ensure
      clear_session
      redirect_to login_path, notice: 'Successfully logged out!'
    end
  end
  
  private
  
  def store_session(auth_response)
    session[:access_token] = auth_response[:access_token]
    session[:refresh_token] = auth_response[:refresh_token]
    session[:user_id] = auth_response[:user][:id] if auth_response[:user]
    session[:user_email] = auth_response[:user][:email] if auth_response[:user]
    session[:user_name] = auth_response[:user][:name] if auth_response[:user]
  end
  
  def clear_session
    session[:access_token] = nil
    session[:refresh_token] = nil
    session[:user_id] = nil
    session[:user_email] = nil
    session[:user_name] = nil
    reset_session
  end
end