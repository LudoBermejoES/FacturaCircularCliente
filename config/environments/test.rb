# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Disable eager loading for faster test boot (especially in Capybara)
  config.eager_load = false

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Raise exceptions in test so we can see the actual error
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false
  config.action_controller.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
  
  # Allow test hosts for RSpec and Capybara (including dynamic ports)
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
  config.hosts << "0.0.0.0"
  config.hosts << "web"
  config.hosts << "www.example.com"  # For Rack::Test default host
  config.hosts << "example.com"      # Additional test host
  
  # Allow any port on these hosts for dynamic port allocation
  config.hosts << /\Alocalhost:\d+\z/
  config.hosts << /\A127\.0\.0\.1:\d+\z/  
  config.hosts << /\A0\.0\.0\.0:\d+\z/
  config.hosts << /\Aweb:\d+\z/
end
