# Browser Tests Solution for Docker Environment

## Best Practice: Use Selenium Grid Container

Based on industry best practices (2024), the recommended approach is to use a **separate Selenium container** instead of installing Chromium directly in the application container.

## Implementation Steps

### 1. Update docker-compose.yml

Add a Selenium service to your `docker-compose.yml`:

```yaml
version: '3.8'

services:
  web:
    build: .
    environment:
      - SELENIUM_HOST=selenium
      - SELENIUM_PORT=4444
      - HUB_URL=http://selenium:4444/wd/hub
      - TEST_APP_HOST=http://web:3001
    ports:
      - "3000:3000"
      - "3001:3001"  # Separate port for test server
    depends_on:
      - selenium
    networks:
      - test_network

  selenium:
    image: selenium/standalone-chrome:latest
    # For Apple Silicon (M1/M2), use:
    # image: seleniarm/standalone-chromium:latest
    shm_size: 2gb
    ports:
      - "4444:4444"
      - "7900:7900"  # noVNC port for debugging
    environment:
      - SE_NODE_MAX_SESSIONS=5
      - SE_NODE_SESSION_TIMEOUT=300
      - SE_VNC_NO_PASSWORD=1
      - SE_SCREEN_WIDTH=1920
      - SE_SCREEN_HEIGHT=1080
    networks:
      - test_network

networks:
  test_network:
    driver: bridge
```

### 2. Update Capybara Configuration

Replace `/spec/support/capybara.rb` with:

```ruby
require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Capybara for Docker environment
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
    # Fallback to local Chrome
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options
    )
  end
end

# Configure Capybara settings
Capybara.configure do |config|
  config.javascript_driver = :selenium_remote
  config.default_driver = :rack_test
  config.default_max_wait_time = 10
  
  # Allow external connections in Docker
  config.server_host = '0.0.0.0'
  config.server_port = 3001
  
  # Set app host for remote browser
  if ENV['TEST_APP_HOST'].present?
    config.app_host = ENV['TEST_APP_HOST']
  end
end

RSpec.configure do |config|
  config.before(:each, type: :feature, js: true) do
    # Ensure we're using the right driver
    Capybara.current_driver = :selenium_remote
    
    # Set the host that the remote browser will connect to
    host = Socket.ip_address_list
                 .find { |ai| ai.ipv4? && !ai.ipv4_loopback? }
                 .ip_address
    Capybara.app_host = "http://#{host}:3001"
  end
  
  config.after(:each, type: :feature, js: true) do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
```

### 3. Update WebMock Configuration

In `spec/rails_helper.rb`, update WebMock to allow Selenium connections:

```ruby
if Rails.env.test?
  WebMock.disable_net_connect!(
    allow_localhost: true,
    allow: [
      'selenium',          # Selenium container hostname
      'chrome',           # Alternative Chrome container hostname
      '0.0.0.0',
      '127.0.0.1',
      /selenium/,         # Any selenium-related host
      /4444/,            # Selenium port
      /.*__identify__.*/  # Capybara's identify endpoint
    ]
  )
end
```

### 4. Update Gemfile

Ensure you have the correct gems (remove `webdrivers` if present):

```ruby
group :test do
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.22'
  gem 'rspec-rails'
  # Remove: gem 'webdrivers'  # Not needed with Selenium Grid
end
```

### 5. Create Test Script

Create a script to run browser tests:

```bash
#!/bin/bash
# bin/test_browser

echo "Starting Selenium container..."
docker-compose up -d selenium

echo "Waiting for Selenium to be ready..."
sleep 5

echo "Running browser tests..."
docker-compose exec -e RAILS_ENV=test web bundle exec rspec spec/features --format documentation

echo "Stopping Selenium container..."
docker-compose stop selenium
```

### 6. Alternative: Use Cuprite (Pure Ruby Solution)

For a simpler setup without Selenium, consider using Cuprite with Ferrum:

```ruby
# Gemfile
group :test do
  gem 'cuprite'
end

# spec/support/cuprite.rb
require 'capybara/cuprite'

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    browser_options: {
      'no-sandbox': true,
      'disable-gpu': true,
      'disable-dev-shm-usage': true
    },
    process_timeout: 30,
    timeout: 30,
    headless: true
  )
end

Capybara.javascript_driver = :cuprite
```

## Running Tests

### With Selenium Grid:
```bash
# Start all services
docker-compose up -d

# Run feature tests
docker-compose exec web bundle exec rspec spec/features

# View browser via noVNC (for debugging)
# Open browser to http://localhost:7900
```

### Debugging Tips:

1. **View Browser Session**: Connect to http://localhost:7900 to see the browser in action
2. **Check Selenium Logs**: `docker-compose logs selenium`
3. **Increase Timeouts**: Set `Capybara.default_max_wait_time = 30` for slow containers
4. **Save Screenshots on Failure**:
```ruby
RSpec.configure do |config|
  config.after(:each, type: :feature, js: true) do |example|
    if example.exception
      save_screenshot("tmp/screenshots/#{example.full_description}.png")
    end
  end
end
```

## Platform-Specific Notes

### Apple Silicon (M1/M2)
Use `seleniarm/standalone-chromium:latest` instead of `selenium/standalone-chrome:latest`

### CI/CD Environments
The same configuration works in CI. Just ensure:
- Docker-in-Docker or Docker socket mounting is available
- Sufficient memory allocation (2GB+ for Chrome)
- Network configuration allows container-to-container communication

## Advantages of This Approach

1. **Isolation**: Browser runs in separate container
2. **Consistency**: Same browser version across all environments
3. **Debugging**: Can watch tests run via VNC
4. **CI-Ready**: Works identically in CI/CD pipelines
5. **No Installation**: No need to install Chrome/ChromeDriver in app container
6. **Platform Agnostic**: Works on Linux, Mac (Intel & Silicon), Windows

## Troubleshooting

### Tests Hanging
- Check Selenium container is running: `docker-compose ps selenium`
- Verify network connectivity: `docker-compose exec web ping selenium`
- Check Selenium status: `curl http://localhost:4444/wd/hub/status`

### Connection Refused
- Ensure `server_host` is set to `0.0.0.0`
- Check firewall/iptables rules
- Verify port 3001 is not in use

### WebMock Blocking Requests
- Add Selenium hostname to WebMock allow list
- Consider using `WebMock.allow_net_connect!` for feature tests

## Conclusion

Using a separate Selenium container is the industry-standard approach for running browser tests in Docker. It provides better isolation, consistency, and debugging capabilities compared to installing browsers directly in the application container.