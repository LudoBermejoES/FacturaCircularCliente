class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :authenticate_user!
  
  rescue_from ApiService::AuthenticationError do |e|
    Rails.logger.error "Authentication error: #{e.message}"
    clear_session
    redirect_to login_path, alert: 'Your session has expired. Please login again.'
  end
  
  rescue_from ApiService::ValidationError do |e|
    Rails.logger.error "Validation error: #{e.message}"
    flash[:alert] = e.message
    redirect_back(fallback_location: root_path)
  end
  
  private
  
  def authenticate_user!
    unless logged_in?
      redirect_to login_path, alert: 'Please login to continue.'
    end
  end
  
  def logged_in?
    current_token.present? && valid_token?
  end
  
  def current_token
    @current_token ||= session[:access_token]
  end
  
  def current_user
    return nil unless logged_in?
    
    @current_user ||= {
      id: session[:user_id],
      email: session[:user_email],
      name: session[:user_name]
    }
  end
  
  def valid_token?
    return false unless current_token.present?
    
    if AuthService.validate_token(current_token)
      true
    else
      try_token_refresh
    end
  end
  
  def try_token_refresh
    return false unless session[:refresh_token].present?
    
    begin
      auth_response = AuthService.refresh_token(session[:refresh_token])
      
      if auth_response
        session[:access_token] = auth_response[:access_token]
        session[:refresh_token] = auth_response[:refresh_token] if auth_response[:refresh_token]
        @current_token = auth_response[:access_token]
        true
      else
        false
      end
    rescue => e
      Rails.logger.error "Token refresh failed: #{e.message}"
      false
    end
  end
  
  def clear_session
    session[:access_token] = nil
    session[:refresh_token] = nil
    session[:user_id] = nil
    session[:user_email] = nil
    session[:user_name] = nil
    @current_token = nil
    @current_user = nil
  end
  
  helper_method :current_user, :logged_in?
end
