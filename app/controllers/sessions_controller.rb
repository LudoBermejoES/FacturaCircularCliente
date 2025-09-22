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
      params[:password],
      params[:company_id] # Optional company_id if user wants to select on login
    )
    
    Rails.logger.info "DEBUG: AuthService returned: #{auth_response ? 'SUCCESS' : 'FAILURE'}"
    
    if auth_response
      Rails.logger.info "DEBUG: Auth successful, storing session"
      Rails.logger.info "DEBUG: Auth response keys: #{auth_response.keys.inspect}"
      store_session(auth_response)

      # If user has multiple companies but no default was selected, show company selector
      if auth_response[:companies]&.size.to_i > 1 && auth_response[:company_id].nil?
        Rails.logger.info "DEBUG: Redirecting to company selector"
        redirect_to select_company_path, notice: 'Please select a company to continue'
      else
        Rails.logger.info "DEBUG: Redirecting to dashboard"
        redirect_to dashboard_path, notice: 'Successfully logged in!'
      end
    else
      Rails.logger.info "DEBUG: Auth failed, auth_response was nil/false"
      flash.now[:alert] = 'Invalid email or password'
      render :new, status: :unprocessable_content
    end
  rescue ApiService::AuthenticationError => e
    Rails.logger.error "DEBUG: Authentication error in create: #{e.message}"
    flash.now[:alert] = 'Invalid credentials'
    render :new, status: :unprocessable_content
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
    Rails.logger.info "DEBUG: store_session called"
    Rails.logger.info "DEBUG: Session ID before storing: #{session.id rescue 'NO_SESSION'}"
    Rails.logger.info "DEBUG: Session keys before storing: #{session.keys.inspect}"

    session[:access_token] = auth_response[:access_token]
    session[:refresh_token] = auth_response[:refresh_token]
    session[:user_id] = auth_response[:user][:id] if auth_response[:user]
    session[:user_email] = auth_response[:user][:email] if auth_response[:user]
    session[:user_name] = auth_response[:user][:name] if auth_response[:user]
    session[:company_id] = auth_response[:company_id]
    session[:companies] = auth_response[:companies]

    Rails.logger.info "DEBUG: Session ID after storing: #{session.id rescue 'NO_SESSION'}"
    Rails.logger.info "DEBUG: Session keys after storing: #{session.keys.inspect}"
    Rails.logger.info "DEBUG: Stored token: #{session[:access_token].present? ? session[:access_token][0..20] + '...' : 'nil'}"
    Rails.logger.info "DEBUG: Stored user_id: #{session[:user_id]}"
    Rails.logger.info "DEBUG: Stored company_id: #{session[:company_id]}"
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