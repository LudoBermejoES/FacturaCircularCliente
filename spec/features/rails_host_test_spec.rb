require 'rails_helper'
require 'net/http'

RSpec.describe 'Rails Host Authorization Test', type: :feature do
  before(:each) do
    WebMock.allow_net_connect!
  end
  
  after(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  it 'allows access to web:3001 from within container' do
    # Test if we can access the Rails app on web:3001 from within the same container
    begin
      response = Net::HTTP.get_response(URI('http://web:3001/'))
      puts "Response code: #{response.code}"
      puts "Response body sample: #{response.body[0..200]}"
      
      expect(response.code.to_i).to be < 500
    rescue => e
      puts "Error connecting to web:3001: #{e.message}"
      puts "This indicates the host authorization issue"
      fail e.message
    end
  end

  it 'shows what hosts are currently allowed' do
    puts "Current Rails.application.config.hosts: #{Rails.application.config.hosts.inspect}"
  end
end