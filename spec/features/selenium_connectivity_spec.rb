require 'rails_helper'
require 'selenium-webdriver'

RSpec.describe 'Selenium Grid Connectivity', type: :feature do
  before(:each) do
    # Allow network connections for Selenium tests
    WebMock.allow_net_connect!
  end
  
  after(:each) do
    # Re-enable WebMock restrictions after tests
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
  let(:hub_url) { ENV['HUB_URL'] || 'http://selenium:4444/wd/hub' }

  it 'can connect to Selenium Grid hub' do
    # Test basic HTTP connectivity to Selenium Grid
    begin
      response = Net::HTTP.get_response(URI("#{hub_url.gsub('/wd/hub', '')}/status"))
      expect(response.code).to eq('200')
      puts "✅ Selenium Grid is accessible at #{hub_url}"
    rescue => e
      fail "❌ Cannot connect to Selenium Grid: #{e.message}"
    end
  end

  it 'can create a WebDriver session', :js do
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')

    begin
      driver = Selenium::WebDriver.for(
        :remote,
        url: hub_url,
        options: options
      )
      
      # Basic test - navigate to a simple page
      driver.navigate.to('data:text/html,<html><head><title>Test</title></head><body><h1>Test Page</h1></body></html>')
      expect(driver.find_element(:tag_name, 'h1').text).to eq('Test Page')
      puts "✅ WebDriver session created successfully"
      
      driver.quit
    rescue => e
      fail "❌ Cannot create WebDriver session: #{e.message}"
    end
  end

  it 'shows environment configuration' do
    puts "🔍 Environment Configuration:"
    puts "  HUB_URL: #{ENV['HUB_URL']}"
    puts "  TEST_APP_HOST: #{ENV['TEST_APP_HOST']}"
    puts "  CAPYBARA_PORT: #{ENV['CAPYBARA_PORT']}"
    puts "  Capybara.server_port: #{Capybara.server_port}"
    puts "  Capybara.server_host: #{Capybara.server_host}"
  end
end