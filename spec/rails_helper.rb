# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'
require 'simplecov'
require 'factory_bot_rails'
require 'shoulda-matchers'
require 'faker'
require 'rails-controller-testing'

# Start SimpleCov for code coverage
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers', 'app/helpers'
  add_group 'JavaScript', 'app/javascript'
end

# Configure VCR for API recording - only in test environment
if Rails.env.test?
  VCR.configure do |config|
    config.cassette_library_dir = 'spec/cassettes'
    config.hook_into :webmock
    config.configure_rspec_metadata!
    config.ignore_localhost = true
    
    # Filter sensitive data
    config.filter_sensitive_data('<JWT_TOKEN>') do |interaction|
      if interaction.request.headers['Authorization']
        interaction.request.headers['Authorization'].first
      end
    end
    
    config.filter_sensitive_data('<API_KEY>') do |interaction|
      ENV['API_KEY']
    end
  end

  # Configure WebMock - only in test environment
  WebMock.disable_net_connect!(
    allow_localhost: true,
    allow: [
      'chromedriver.storage.googleapis.com',
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      /0\.0\.0\.0:\d+/,  # Allow Capybara's server on any port
      'selenium',          # Selenium container hostname
      'web',              # Web container hostname
      /localhost/,
      /127\.0\.0\.1/,
      /0\.0\.0\.0/,
      /selenium/,         # Any selenium-related host
      /4444/,            # Selenium Grid port
      /3001/,            # Test server port
      /__identify__/     # Allow Capybara's internal identify endpoint
    ]
  )
end

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Use ActiveRecord for test database connection (stateless client uses in-memory DB for tests only)
  config.use_active_record = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include controller testing helpers
  [:controller, :view, :request].each do |type|
    config.include ::Rails::Controller::Testing::TestProcess, type: type
    config.include ::Rails::Controller::Testing::TemplateAssertions, type: type
    config.include ::Rails::Controller::Testing::Integration, type: type
  end
  
  # Clean up test data
  config.before(:suite) do
    # No database to clean in this client app
  end
  
  config.after(:each) do
    WebMock.reset! if Rails.env.test?
  end
end
