class DashboardController < ApplicationController
  def index
    begin
      @user = current_user

      companies = user_companies

      # Check if user has any companies assigned
      if companies.empty?
        redirect_to login_path, alert: 'No companies found for your account. Please contact an administrator.'
        return
      end

      # Stats endpoint doesn't exist in API, use defaults
      @stats = { total_invoices: 0, draft_count: 0, sent_count: 0, paid_count: 0, total_amount: 0, pending_amount: 0 }

      token = current_token

      # Recent invoices should still work
      @recent_invoices = InvoiceService.recent(token: token, limit: 5)

    rescue ApiService::AuthenticationError => e
      clear_session
      redirect_to login_path, alert: 'Your session has expired. Please login again.'
    rescue => e
      @stats = { total_invoices: 0, draft_count: 0, sent_count: 0, paid_count: 0, total_amount: 0, pending_amount: 0 }
      @recent_invoices = []
      raise e  # Re-raise so we can see the full error in test
    end
  end
end