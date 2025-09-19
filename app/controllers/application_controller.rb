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
  
  around_action :log_action_execution
  
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
    return if request.path == login_path # Don't authenticate on login page itself

    unless logged_in?
      redirect_to login_path, alert: 'Please sign in to continue'
      return false # Halt the action chain
    end
  rescue => e
    Rails.logger.error "Authentication error: #{e.message}"
    redirect_to login_path, alert: 'Authentication error occurred'
    return false
  end
  
  def authenticate_api_user!
    Rails.logger.info "DEBUG: authenticate_api_user! called for #{request.path}"
    
    unless logged_in?
      Rails.logger.info "DEBUG: User not logged in, returning 401 for API request"
      render json: {
        errors: [{
          status: '401',
          title: 'Authentication Required',
          detail: 'You must be logged in to access this resource'
        }]
      }, status: :unauthorized
      return false
    end
    
    true
  rescue => e
    Rails.logger.error "DEBUG: authenticate_api_user! error: #{e.message}"
    Rails.logger.error "DEBUG: authenticate_api_user! backtrace: #{e.backtrace.first(10).join('\n')}"
    render json: {
      errors: [{
        status: '500',
        title: 'Authentication Error',
        detail: 'An error occurred during authentication'
      }]
    }, status: :internal_server_error
    false
  end
  
  def logged_in?
    has_token = current_token.present?
    return false unless has_token

    token_valid = valid_token?
    has_token && token_valid
  rescue => e
    Rails.logger.error "logged_in? error: #{e.message}"
    false
  end
  
  def user_signed_in?
    logged_in?
  end
  
  def current_token
    new_token = session[:access_token]

    # Clear cache if token changed
    if @current_token != new_token
      @token_valid_cache = nil
      @current_token = new_token
    end

    @current_token
  end
  
  # Alias for current_token
  def current_user_token
    current_token
  end
  
  def current_user
    return nil unless logged_in?
    
    @current_user ||= {
      id: session[:user_id],
      email: session[:user_email],
      name: session[:user_name],
      company_id: session[:company_id],
      companies: session[:companies] || []
    }
  end
  
  def current_company_id
    session[:company_id]
  end
  
  def current_company
    return nil unless current_company_id
    
    @current_company ||= session[:companies]&.find { |c| c['id'] == current_company_id || c[:id] == current_company_id }
  end
  
  def user_companies
    session[:companies] || []
  end
  
  def valid_token?
    return false unless current_token.present?

    # Cache token validation result for the duration of the request (except in tests)
    if !Rails.env.test? && defined?(@token_valid_cache)
      return @token_valid_cache
    end

    begin
      result = AuthService.validate_token(current_token)

      if result && result[:valid]
        @token_valid_cache = true
        true
      else
        @token_valid_cache = try_token_refresh
        @token_valid_cache
      end
    rescue => e
      Rails.logger.error "valid_token? error: #{e.message}"
      @token_valid_cache = false
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
        # Clear token validation cache since we have a new token
        @token_valid_cache = nil
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
    session[:company_id] = nil
    session[:companies] = nil
    @current_token = nil
    @current_user = nil
    @current_company = nil
    @token_valid_cache = nil
  end
  
  # Permission helpers
  def current_user_role
    return nil unless current_company_id && user_companies.present?
    
    company = user_companies.find { |c| (c['id'] || c[:id]) == current_company_id }
    company ? (company['role'] || company[:role]) : nil
  end
  
  def can?(action, resource = nil)
    role = current_user_role
    return false unless role
    
    case role
    when 'owner'
      true # Owners can do everything
    when 'admin'
      # Admins can do most things except manage owners
      ![:manage_owners, :delete_company].include?(action)
    when 'manager'
      [:view, :create, :edit, :approve, :manage_invoices, :manage_workflows].include?(action)
    when 'accountant'
      [:view, :create, :edit, :manage_invoices, :export, :generate_reports].include?(action)
    when 'reviewer'
      [:view, :review, :approve].include?(action)
    when 'submitter'
      [:view, :create, :submit].include?(action)
    when 'viewer'
      [:view].include?(action)
    else
      false
    end
  end
  
  def ensure_can!(action, resource = nil)
    unless can?(action, resource)
      redirect_to dashboard_path, alert: 'You do not have permission to perform this action.'
    end
  end
  
  helper_method :current_user, :logged_in?, :user_signed_in?, :current_company, :current_company_id, :user_companies, :current_user_role, :can?, :current_token
  
  def log_action_execution
    Rails.logger.info "AROUND_ACTION: Starting #{controller_name}##{action_name}"
    begin
      yield
      Rails.logger.info "AROUND_ACTION: Completed #{controller_name}##{action_name} with status #{response.status}"
    rescue => e
      Rails.logger.error "AROUND_ACTION: Error in #{controller_name}##{action_name}: #{e.class} - #{e.message}"
      raise
    end
  end
end
