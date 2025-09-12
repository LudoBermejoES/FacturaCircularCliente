require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Chromium options for headless mode
Capybara.register_driver :chrome do |app|
  chrome_options = Selenium::WebDriver::Chrome::Options.new
  chrome_options.binary = '/usr/bin/chromium'
  chrome_options.add_argument('--headless=new')  # Use new headless mode
  chrome_options.add_argument('--no-sandbox')
  chrome_options.add_argument('--disable-dev-shm-usage')
  chrome_options.add_argument('--disable-gpu')
  chrome_options.add_argument('--window-size=1400,1400')
  chrome_options.add_argument('--remote-debugging-port=9222')
  chrome_options.add_argument('--disable-extensions')
  chrome_options.add_argument('--disable-blink-features=AutomationControlled')
  chrome_options.add_argument('--disable-software-rasterizer')
  
  # Specify chromedriver path explicitly
  service = Selenium::WebDriver::Service.chrome(path: '/usr/bin/chromedriver')
  
  # Add timeout configuration
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120
  client.open_timeout = 120
  
  Capybara::Selenium::Driver.new(app, 
    browser: :chrome, 
    options: chrome_options, 
    service: service,
    http_client: client
  )
end

# Configure Chromium for debugging (non-headless)
Capybara.register_driver :chrome_debug do |app|
  chrome_options = Selenium::WebDriver::Chrome::Options.new
  chrome_options.binary = '/usr/bin/chromium'
  chrome_options.add_argument('--no-sandbox')
  chrome_options.add_argument('--disable-dev-shm-usage')
  chrome_options.add_argument('--window-size=1400,1400')
  
  # Specify chromedriver path explicitly
  service = Selenium::WebDriver::Service.chrome(path: '/usr/bin/chromedriver')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options, service: service)
end

# Set default driver for JavaScript tests
Capybara.javascript_driver = :chrome
Capybara.default_driver = :rack_test

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    # Let Capybara start its own test server on a random port
    Capybara.server_host = '0.0.0.0'
    Capybara.server_port = 0  # 0 means random available port
    Capybara.app_host = nil   # Let Capybara manage this
  end
  
  config.before(:each, type: :system) do
    # Let Capybara start its own test server on a random port
    Capybara.server_host = '0.0.0.0'
    Capybara.server_port = 0  # 0 means random available port
    Capybara.app_host = nil   # Let Capybara manage this
  end
end

Capybara.configure do |config|
  config.default_max_wait_time = 5
  config.server = :puma, { Silent: true }
  # Remove app_host and default_host to let Capybara manage them
end