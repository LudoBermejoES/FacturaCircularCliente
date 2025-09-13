# Test fixes for common issues identified in focused analysis

RSpec.configure do |config|
  # Fix port conflicts by resetting Capybara configuration before each feature test
  config.before(:each, type: :feature) do
    # Reset all sessions to clean up any existing servers
    Capybara.reset_sessions!
    
    # Ensure we use dynamic port allocation to avoid conflicts
    Capybara.server_port = 0
    
    # Clear app_host so it gets recalculated
    Capybara.app_host = nil
  end
  
  # Ensure proper cleanup after feature tests
  config.after(:each, type: :feature) do
    # Reset sessions and use default driver
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
  
  # Fix VCR blocking issues for feature tests
  config.before(:each, type: :feature, js: true) do
    # Completely disable VCR for JavaScript feature tests since they need real browser interactions
    VCR.turn_off!(ignore_cassettes: true)
    WebMock.allow_net_connect!
  end
  
  config.after(:each, type: :feature, js: true) do
    # Re-enable VCR after JavaScript tests
    VCR.turn_on!
    
    # Re-configure WebMock with proper allowances
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        'chromedriver.storage.googleapis.com',
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        /0\.0\.0\.0:\d+/,
        'selenium',
        'web',
        /selenium/,
        /4444/,        # Selenium Grid port
        /3005/,        # Capybara server port
        /__identify__/ # Capybara identify endpoint
      ]
    )
  end
end

puts "✅ Test fixes loaded - port conflict and VCR blocking fixes applied"