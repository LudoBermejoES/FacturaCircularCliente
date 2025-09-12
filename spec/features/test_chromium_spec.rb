require 'rails_helper'

RSpec.feature 'Chromium Test', type: :feature, js: true do
  before do
    # Allow all localhost connections for Capybara
    WebMock.allow_net_connect!
  end
  
  scenario 'Simple Chromium test' do
    puts "Starting Chromium test..."
    
    # Visit a simple data URL to avoid any routing issues
    visit 'data:text/html,<h1>Hello Chromium</h1>'
    
    expect(page).to have_content('Hello Chromium')
    puts "Test completed successfully!"
  end
end