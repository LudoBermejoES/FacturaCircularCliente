namespace :test do
  desc "Test Selenium Grid connectivity"
  task :selenium => :environment do
    require 'net/http'
    require 'json'

    puts "Testing Selenium Grid connectivity..."
    puts "=" * 50

    hub_url = ENV['HUB_URL'] || 'http://selenium:4444/wd/hub'
    puts "HUB_URL: #{hub_url}"

    begin
      uri = URI.parse(hub_url.gsub('/wd/hub', ''))
      base_uri = "#{uri.scheme}://#{uri.host}:#{uri.port}"

      # Test /status endpoint
      puts "\nTesting #{base_uri}/status endpoint..."
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5

      response = http.get('/status')
      puts "Status Code: #{response.code}"

      if response.code == '200'
        json = JSON.parse(response.body) rescue {}
        ready = json.dig('value', 'ready') || json['ready']

        puts "Grid Ready: #{ready}"
        puts "Grid Message: #{json.dig('value', 'message') || json['message']}"

        # Try to get node status
        nodes = json.dig('value', 'nodes') || json['nodes'] || []
        if nodes.any?
          puts "\nNodes available: #{nodes.count}"
          nodes.each_with_index do |node, i|
            puts "  Node #{i + 1}: #{node['status'] || node['availability'] || 'Unknown status'}"
          end
        else
          puts "\nNo nodes reported (this might be normal for standalone mode)"
        end

        puts "\n✅ Selenium Grid is accessible and ready!"

        # Test creating a session
        puts "\nTesting session creation..."
        require 'selenium-webdriver'

        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')

        client = Selenium::WebDriver::Remote::Http::Default.new
        client.open_timeout = 30
        client.read_timeout = 30

        begin
          driver = Selenium::WebDriver.for(
            :remote,
            url: hub_url,
            options: options,
            http_client: client
          )

          puts "✅ Successfully created a browser session!"

          # Try to navigate to a simple page
          driver.navigate.to "data:text/html,<h1>Test Page</h1>"
          title = driver.execute_script("return document.querySelector('h1').textContent")
          puts "✅ Browser can execute JavaScript. Page title: #{title}"

          driver.quit
          puts "✅ Session closed successfully!"

        rescue => e
          puts "❌ Failed to create browser session: #{e.message}"
          puts "   This might be due to browser compatibility issues."
        end

      else
        puts "❌ Selenium Grid returned unexpected status: #{response.code}"
        puts "Response body: #{response.body}"
      end

    rescue Errno::ECONNREFUSED => e
      puts "❌ Cannot connect to Selenium Grid at #{hub_url}"
      puts "   Error: Connection refused"
      puts "\nTroubleshooting:"
      puts "1. Check if Selenium container is running: docker-compose ps"
      puts "2. Check Selenium logs: docker-compose logs selenium"
      puts "3. Verify network connectivity between containers"

    rescue => e
      puts "❌ Unexpected error: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    puts "\n" + "=" * 50
    puts "Test complete"
  end

  desc "Run system tests with debug output"
  task :system_debug => :environment do
    ENV['DEBUG_TESTS'] = '1'
    ENV['VERBOSE_TESTS'] = '1'

    puts "Running system tests with debug output..."
    system("RAILS_ENV=test DEBUG_TESTS=1 VERBOSE_TESTS=1 bundle exec rspec spec/system/ --format documentation")
  end
end