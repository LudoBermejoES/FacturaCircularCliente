require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Configure Chrome with unique user data directory for each test process
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_option|
    # Create unique user data directory for each test process to avoid conflicts
    unique_id = "#{Process.pid}_#{Time.now.to_i}_#{rand(1000)}"
    user_data_dir = "/tmp/chrome_test_#{unique_id}"

    driver_option.add_argument("--user-data-dir=#{user_data_dir}")
    driver_option.add_argument("--no-sandbox")
    driver_option.add_argument("--disable-dev-shm-usage")
    driver_option.add_argument("--disable-gpu")
    driver_option.add_argument("--remote-debugging-port=0")
    driver_option.add_argument("--disable-features=VizDisplayCompositor")
  end

  # Helper method for system test authentication
  def sign_in_for_system_test(role: "admin", company_id: 1)
    # Mock the services that will be called during login and navigation
    # Set up auth response with single company to go directly to dashboard
    AuthService.stubs(:login).returns({
      access_token: "test_#{role}_token",
      refresh_token: "test_refresh_token",
      user: {
        id: 1,
        email: "#{role}@example.com",
        name: "#{role.capitalize} User",
        company_id: company_id
      },
      company_id: company_id,  # Set company_id to go directly to dashboard
      companies: [{ id: company_id, name: "Test Company", role: role }]
    })

    AuthService.stubs(:validate_token).returns({ valid: true })
    InvoiceService.stubs(:recent).returns([])

    # Mock workflow and other services that might be called
    WorkflowService.stubs(:definitions).returns({ data: [] })
    CompanyService.stubs(:all).returns({ companies: [] })

    # Visit login page and fill out form
    visit login_path
    fill_in "Email", with: "#{role}@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"

    # Should redirect directly to dashboard since company_id is set
    # Wait for dashboard to load - check for visible dashboard content
    assert_text "Welcome back", wait: 5
  end
end
