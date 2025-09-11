class DashboardController < ApplicationController
  def index
    @user = current_user
    @stats = InvoiceService.stats(token: current_token)
    @recent_invoices = InvoiceService.recent(token: current_token, limit: 5)
  rescue ApiService::AuthenticationError => e
    clear_session
    redirect_to login_path, alert: 'Your session has expired. Please login again.'
  rescue => e
    Rails.logger.error "Dashboard error: #{e.message}"
    @stats = { total_invoices: 0, draft_count: 0, sent_count: 0, paid_count: 0, total_amount: 0, pending_amount: 0 }
    @recent_invoices = []
  end
end