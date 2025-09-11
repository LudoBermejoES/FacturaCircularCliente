module SessionHelper
  def login_via_ui(email = 'admin@example.com', password = 'password123')
    visit login_path
    fill_in 'Email address', with: email
    fill_in 'Password', with: password
    click_button 'Sign in'
  end
  
  def logout_via_ui
    find('[data-dropdown-target="button"]').click
    click_link 'Sign out'
  end
  
  def expect_to_be_logged_in
    expect(page).to have_content('Dashboard')
    expect(page).not_to have_content('Sign in to FacturaCircular')
  end
  
  def expect_to_be_logged_out
    expect(page).to have_content('Sign in to FacturaCircular')
    expect(page).not_to have_content('Dashboard')
  end
  
  def expect_authentication_error
    expect(page).to have_content('Please sign in to continue')
  end
  
  def with_authenticated_session(&block)
    login_via_ui
    expect_to_be_logged_in
    yield if block_given?
    logout_via_ui
    expect_to_be_logged_out
  end
end

RSpec.configure do |config|
  config.include SessionHelper, type: :feature
  config.include SessionHelper, type: :system
end