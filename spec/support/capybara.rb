require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Selenium Grid driver for remote browser with enhanced timeouts
Capybara.register_driver :selenium_remote do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-software-rasterizer')
  # Add more stability arguments
  options.add_argument('--disable-blink-features=AutomationControlled')
  options.add_argument('--disable-features=VizDisplayCompositor')
  options.add_argument('--disable-translate')
  options.add_argument('--disable-background-timer-throttling')
  options.add_argument('--disable-renderer-backgrounding')
  options.add_argument('--disable-features=TranslateUI')
  options.add_argument('--disable-ipc-flooding-protection')

  client = Selenium::WebDriver::Remote::Http::Default.new
  client.open_timeout = 120  # Increase from default 60
  client.read_timeout = 120  # Increase from default 60

  if ENV['HUB_URL'].present?
    # Use remote Selenium Grid with increased timeouts
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: ENV['HUB_URL'],
      options: options,
      http_client: client
    )
  else
    # Fallback to local Chrome (for local development)
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options,
      http_client: client
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

# Configure Capybara settings with increased timeouts
Capybara.configure do |config|
  config.default_max_wait_time = 15  # Increased from 10
  config.server = :puma, {
    Silent: true,
    Threads: "1:1",
    workers: 0,  # Disable clustering for faster boot
    preload_app: false,  # Disable app preloading to prevent initialization blocks
    queue_requests: false,
    Verbose: false
  }

  # Allow external connections in Docker
  config.server_host = '0.0.0.0'
  config.server_port = 0  # Let Capybara choose available port automatically

  # Set app host for remote browser if provided
  if ENV['TEST_APP_HOST'].present?
    config.app_host = ENV['TEST_APP_HOST']
  else
    # Force localhost for rack_test driver to avoid host blocking issues
    config.app_host = 'http://localhost'
  end
end

# Increase server boot timeout for Docker environment (5 minutes)
# Note: server_boot_timeout is not available in all Capybara versions
# Use environment variable instead
ENV['CAPYBARA_SERVER_TIMEOUT'] = '300'

# Set Capybara server timeout if method is available
if Capybara.respond_to?(:server_boot_timeout=)
  Capybara.server_boot_timeout = 300
end

RSpec.configure do |config|
  # Configure feature tests to use Rack::Test by default to avoid server boot timeout
  config.before(:each, type: :feature) do |example|
    # Use Rack::Test for all feature tests unless explicitly marked for server testing
    if example.metadata[:server_test]
      # Only use server-based testing when explicitly requested and working
      Capybara.current_driver = :selenium_remote

      # Allow dynamic app_host configuration for server tests
      if ENV['HUB_URL'].present?
        Capybara.app_host = nil  # Let Capybara auto-configure
      end
      puts "🔧 Using Selenium server for feature test: #{example.description}" if ENV['VERBOSE_TESTS']
    else
      # Use Rack::Test to avoid server boot timeout issues
      Capybara.current_driver = :rack_test
      puts "🔧 Using Rack::Test for feature test: #{example.description}" if ENV['VERBOSE_TESTS']
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