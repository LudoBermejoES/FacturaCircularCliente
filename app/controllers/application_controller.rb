class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern  # Disabled for testing
  
  # Disable CSRF protection in test environment
  if Rails.env.test?
    skip_forgery_protection
  else
    protect_from_forgery with: :exception
  end
  
  before_action :debug_request
  before_action :authenticate_user!
  
  rescue_from ApiService::AuthenticationError do |e|
    Rails.logger.error "Authentication error: #{e.message}"
    clear_session
    redirect_to login_path, alert: 'Your session has expired. Please login again.'
  end
  
  
  private
  
  def debug_request
    Rails.logger.info "DEBUG: Processing #{request.method} #{request.path}"
    Rails.logger.info "DEBUG: Controller: #{self.class.name}"
    Rails.logger.info "DEBUG: Action: #{action_name}"
    Rails.logger.info "DEBUG: Current token: #{session[:access_token].present? ? 'present' : 'nil'}"
  rescue => e
    Rails.logger.error "DEBUG ERROR: #{e.message}"
    Rails.logger.error "DEBUG BACKTRACE: #{e.backtrace.first(5).join('\n')}"
    raise e
  end
  
  def authenticate_user!
    Rails.logger.info "DEBUG: authenticate_user! called for #{request.path}"
    return if request.path == login_path # Don't authenticate on login page itself
    
    unless logged_in?
      Rails.logger.info "DEBUG: User not logged in, redirecting to login"
      redirect_to login_path, alert: 'Please sign in to continue'
    end
  rescue => e
    Rails.logger.error "DEBUG: authenticate_user! error: #{e.message}"
    Rails.logger.error "DEBUG: authenticate_user! backtrace: #{e.backtrace.first(10).join('\n')}"
    raise e
  end
  
  def logged_in?
    Rails.logger.info "DEBUG: logged_in? called"
    has_token = current_token.present?
    Rails.logger.info "DEBUG: current_token present: #{has_token}"
    
    return false unless has_token
    
    token_valid = valid_token?
    Rails.logger.info "DEBUG: valid_token?: #{token_valid}"
    
    has_token && token_valid
  rescue => e
    Rails.logger.error "DEBUG: logged_in? error: #{e.message}"
    Rails.logger.error "DEBUG: logged_in? backtrace: #{e.backtrace.first(5).join('\n')}"
    false
  end
  
  def user_signed_in?
    logged_in?
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
    Rails.logger.info "DEBUG: valid_token? called"
    return false unless current_token.present?
    
    begin
      Rails.logger.info "DEBUG: Calling AuthService.validate_token"
      result = AuthService.validate_token(current_token)
      Rails.logger.info "DEBUG: AuthService.validate_token returned: #{result.inspect}"
      
      if result
        true
      else
        Rails.logger.info "DEBUG: Token invalid, trying refresh"
        try_token_refresh
      end
    rescue => e
      Rails.logger.error "DEBUG: valid_token? error: #{e.message}"
      Rails.logger.error "DEBUG: valid_token? backtrace: #{e.backtrace.first(5).join('\n')}"
      false
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
  
  helper_method :current_user, :logged_in?, :user_signed_in?
end
