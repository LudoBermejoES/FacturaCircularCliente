require 'rails_helper'

RSpec.describe 'Capybara Debug', type: :feature do
  it 'debugs Capybara server startup' do
    puts "Capybara settings:"
    puts "  server_host: #{Capybara.server_host}"
    puts "  server_port: #{Capybara.server_port}"
    puts "  app_host: #{Capybara.app_host}"
    puts "  default_driver: #{Capybara.default_driver}"
    puts "  javascript_driver: #{Capybara.javascript_driver}"
    
    # Test without JavaScript first
    puts "\nTesting without JavaScript (rack_test driver)..."
    Capybara.current_driver = :rack_test
    visit '/login'
    puts "Successfully visited /login with rack_test"
    expect(page.status_code).to eq(200)
  end
end