require 'capybara/rails'
require 'capybara/rspec'

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
end