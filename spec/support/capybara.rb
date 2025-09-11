require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Chromium options for headless mode
Capybara.register_driver :chrome do |app|
  chrome_options = Selenium::WebDriver::Chrome::Options.new
  chrome_options.binary = '/usr/bin/chromium'
  chrome_options.add_argument('--headless')
  chrome_options.add_argument('--no-sandbox')
  chrome_options.add_argument('--disable-dev-shm-usage')
  chrome_options.add_argument('--disable-gpu')
  chrome_options.add_argument('--window-size=1400,1400')
  chrome_options.add_argument('--remote-debugging-port=9222')
  chrome_options.add_argument('--disable-extensions')
  chrome_options.add_argument('--disable-web-security')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options)
end

# Configure Chromium for debugging (non-headless)
Capybara.register_driver :chrome_debug do |app|
  chrome_options = Selenium::WebDriver::Chrome::Options.new
  chrome_options.binary = '/usr/bin/chromium'
  chrome_options.add_argument('--no-sandbox')
  chrome_options.add_argument('--disable-dev-shm-usage')
  chrome_options.add_argument('--window-size=1400,1400')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options)
end

# Set default driver for JavaScript tests
Capybara.javascript_driver = :chrome
Capybara.default_driver = :rack_test

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.app_host = 'http://localhost:3002'
    Capybara.server_host = 'localhost'
    Capybara.server_port = 3002
  end
  
  config.before(:each, type: :system) do
    Capybara.app_host = 'http://localhost:3002'
    Capybara.server_host = 'localhost'
    Capybara.server_port = 3002
  end
end

Capybara.configure do |config|
  config.default_host = 'http://localhost:3002'
  config.app_host = 'http://localhost:3002'
  config.default_max_wait_time = 5
  config.server = :puma, { Silent: true }
end