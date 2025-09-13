require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Selenium Grid driver for remote browser
Capybara.register_driver :selenium_remote do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-software-rasterizer')

  if ENV['HUB_URL'].present?
    # Use remote Selenium Grid
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: ENV['HUB_URL'],
      options: options
    )
  else
    # Fallback to local Chrome (for local development)
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options
    )
  end
end

# Configure driver for debugging (non-headless)
Capybara.register_driver :selenium_remote_debug do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1920,1080')
  
  if ENV['HUB_URL'].present?
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: ENV['HUB_URL'],
      options: options
    )
  else
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options
    )
  end
end

# Set default drivers
Capybara.javascript_driver = :selenium_remote
Capybara.default_driver = :rack_test

# Configure Capybara settings
Capybara.configure do |config|
  config.default_max_wait_time = 10
  config.server = :puma, { Silent: true, Threads: "0:1" }
  
  # Allow external connections in Docker
  config.server_host = '0.0.0.0'
  config.server_port = ENV['CAPYBARA_PORT']&.to_i || 3005  # Use port 3005 to avoid conflicts with dev server
  
  # Set app host for remote browser if provided
  if ENV['TEST_APP_HOST'].present?
    config.app_host = ENV['TEST_APP_HOST']
  end
end

RSpec.configure do |config|
  config.before(:each, type: :feature, js: true) do
    # Allow WebMock to permit Capybara connections
    WebMock.allow_net_connect!
    
    # Ensure we're using the remote driver for JS tests
    Capybara.current_driver = :selenium_remote
    
    # Set the host that the remote browser will connect to
    if ENV['HUB_URL'].present?
      # Use the fixed Capybara port (3005)
      Capybara.app_host = "http://web:#{Capybara.server_port}"
      puts "🔗 Setting Capybara.app_host to: #{Capybara.app_host}"
    end
  end
  
  config.after(:each, type: :feature, js: true) do
    Capybara.reset_sessions!
    Capybara.use_default_driver
    
    # Re-enable WebMock restrictions after feature tests
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
        /__identify__/
      ]
    )
  end
  
  # Save screenshots on failure
  config.after(:each, type: :feature, js: true) do |example|
    if example.exception
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      screenshot_path = "tmp/screenshots/#{example.full_description.gsub(/[^a-z0-9]/i, '_')}_#{timestamp}.png"
      save_screenshot(screenshot_path)
      puts "Screenshot saved: #{screenshot_path}"
    end
  end
end