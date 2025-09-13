# This file is loaded early in the initialization process (01_ prefix)
# to configure hosts before the ActionDispatch::HostAuthorization middleware loads

if Rails.env.test?
  Rails.logger&.info("Setting up allowed hosts for test environment")
  
  Rails.application.config.hosts << "localhost"
  Rails.application.config.hosts << "127.0.0.1"
  Rails.application.config.hosts << "0.0.0.0"
  Rails.application.config.hosts << "web"
  Rails.application.config.hosts << "web:3005"  # Capybara test server
  Rails.application.config.hosts << "www.example.com"
  Rails.application.config.hosts << "test.host"
  
  Rails.logger&.info("Allowed hosts: #{Rails.application.config.hosts}")
end