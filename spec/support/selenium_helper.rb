# Helper module for Selenium connectivity and fallback handling
module SeleniumHelper
  extend self

  # Check if Selenium Grid is available and responsive
  def selenium_available?
    return false unless ENV['HUB_URL'].present?

    begin
      require 'net/http'
      uri = URI.parse(ENV['HUB_URL'])
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5

      # Try to get the status endpoint
      response = http.get('/status')

      if response.code == '200'
        json = JSON.parse(response.body) rescue {}
        ready = json.dig('value', 'ready') || json['ready']

        if ready
          puts "✓ Selenium Grid is ready at #{ENV['HUB_URL']}" if ENV['DEBUG_TESTS']
          return true
        else
          puts "⚠ Selenium Grid not ready: #{json}" if ENV['DEBUG_TESTS']
          return false
        end
      else
        puts "⚠ Selenium Grid returned status #{response.code}" if ENV['DEBUG_TESTS']
        return false
      end
    rescue => e
      puts "⚠ Cannot connect to Selenium Grid: #{e.message}" if ENV['DEBUG_TESTS']
      return false
    end
  end

  # Choose appropriate driver based on test requirements and availability
  def choose_driver(javascript_required: false)
    if javascript_required && selenium_available?
      :selenium_remote
    elsif javascript_required && !selenium_available?
      puts "⚠️ WARNING: JavaScript test requires Selenium but it's not available. Test may fail." if ENV['DEBUG_TESTS']
      :rack_test
    else
      # For non-JS tests, prefer rack_test for speed
      :rack_test
    end
  end

  # Wrapper for safely setting driver with fallback
  def use_driver_with_fallback(javascript_required: false)
    driver = choose_driver(javascript_required: javascript_required)
    Capybara.current_driver = driver
    puts "  Using driver: #{driver}" if ENV['VERBOSE_TESTS']
    driver
  end
end

# Include helper in RSpec configuration
RSpec.configure do |config|
  config.include SeleniumHelper, type: :system

  # Automatic driver selection for system tests
  config.before(:each, type: :system) do |example|
    # Check if test is marked as requiring JavaScript
    js_required = example.metadata[:js] || example.metadata[:javascript]

    # Use helper to choose and set appropriate driver
    use_driver_with_fallback(javascript_required: js_required)
  end

  # Reset driver after each test
  config.after(:each, type: :system) do
    Capybara.use_default_driver
  end
end