# Authentication helpers for RSpec migration from Minitest patterns
# Incorporates the successful setup_authenticated_session pattern

module AuthenticationHelpers
  # Main authentication helper - mirrors the successful Minitest pattern
  def setup_authenticated_session(role: "viewer", company_id: 1, companies: nil)
    # Mock authentication methods
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return("test_token")
    allow_any_instance_of(ApplicationController).to receive(:current_company_id).and_return(company_id)

    if company_id && companies&.any?
      current_company = companies.find { |c| c['id'] == company_id }
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(current_company)
    else
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(nil)
    end

    allow_any_instance_of(ApplicationController).to receive(:user_companies).and_return(companies || [])
    allow_any_instance_of(ApplicationController).to receive(:current_user_role).and_return(role)
    allow_any_instance_of(ApplicationController).to receive(:can?).and_return(true)
  end

  # Alternative pattern for when you need UI-based login
  def login_via_ui(email = 'admin@example.com', password = 'password123')
    visit login_path
    within 'form' do
      find('input[type="email"]').set(email)
      find('input[type="password"]').set(password)
      click_button 'Sign in'
    end
  end

  def logout_via_ui
    find('[data-action="click->dropdown#toggle"]').click
    click_button 'Sign out'
  end

  def expect_to_be_logged_in
    expect(page).to have_content('Dashboard')
    expect(page).not_to have_content('Sign in to FacturaCircular')
  end

  def expect_to_be_logged_out
    expect(page).to have_content('Sign in to FacturaCircular')
    expect(page).not_to have_content('Dashboard')
  end

  def expect_authentication_error
    expect(page).to have_content('Please sign in to continue')
  end

  def with_authenticated_session(&block)
    login_via_ui
    expect_to_be_logged_in
    yield if block_given?
    logout_via_ui
    expect_to_be_logged_out
  end

  # Shorthand helpers for common test scenarios
  def authenticate_as_admin(company_id: 1999)
    setup_authenticated_session(role: "admin", company_id: company_id)
  end

  def authenticate_as_manager(company_id: 1)
    setup_authenticated_session(role: "manager", company_id: company_id)
  end

  def authenticate_as_viewer(company_id: 1)
    setup_authenticated_session(role: "viewer", company_id: company_id)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :feature
  config.include AuthenticationHelpers, type: :system
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :controller
end