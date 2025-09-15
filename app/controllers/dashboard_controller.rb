class DashboardController < ApplicationController
  def index
    Rails.logger.info "🔍 DASHBOARD DEBUG: Starting dashboard#index"
    
    begin
      Rails.logger.info "🔍 DASHBOARD DEBUG: Getting current_user"
      @user = current_user
      Rails.logger.info "🔍 DASHBOARD DEBUG: @user = #{@user.inspect}"
      
      Rails.logger.info "🔍 DASHBOARD DEBUG: Getting user_companies"
      companies = user_companies
      Rails.logger.info "🔍 DASHBOARD DEBUG: user_companies = #{companies.inspect}"
      
      # Check if user has any companies assigned
      if companies.empty?
        Rails.logger.info "🔍 DASHBOARD DEBUG: No companies found, redirecting"
        redirect_to login_path, alert: 'No companies found for your account. Please contact an administrator.'
        return
      end
      
      Rails.logger.info "🔍 DASHBOARD DEBUG: Setting up stats"
      # Stats endpoint doesn't exist in API, use defaults
      @stats = { total_invoices: 0, draft_count: 0, sent_count: 0, paid_count: 0, total_amount: 0, pending_amount: 0 }
      
      Rails.logger.info "🔍 DASHBOARD DEBUG: Getting current_token"
      token = current_token
      Rails.logger.info "🔍 DASHBOARD DEBUG: current_token = #{token.inspect}"
      
      Rails.logger.info "🔍 DASHBOARD DEBUG: Calling InvoiceService.recent"
      # Recent invoices should still work
      @recent_invoices = InvoiceService.recent(token: token, limit: 5)
      Rails.logger.info "🔍 DASHBOARD DEBUG: @recent_invoices = #{@recent_invoices.inspect}"
      
      Rails.logger.info "🔍 DASHBOARD DEBUG: Dashboard#index completed successfully"
    rescue ApiService::AuthenticationError => e
      Rails.logger.error "🔍 DASHBOARD DEBUG: AuthenticationError: #{e.message}"
      Rails.logger.error "🔍 DASHBOARD DEBUG: #{e.backtrace.first(5).join('\n')}"
      clear_session
      redirect_to login_path, alert: 'Your session has expired. Please login again.'
    rescue => e
      Rails.logger.error "🔍 DASHBOARD DEBUG: General error: #{e.class} - #{e.message}"
      Rails.logger.error "🔍 DASHBOARD DEBUG: #{e.backtrace.first(10).join('\n')}"
      @stats = { total_invoices: 0, draft_count: 0, sent_count: 0, paid_count: 0, total_amount: 0, pending_amount: 0 }
      @recent_invoices = []
      raise e  # Re-raise so we can see the full error in test
    end
  end
end