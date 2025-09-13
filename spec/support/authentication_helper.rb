module AuthenticationHelper
  def login_as(user = nil)
    user ||= { id: 1, email: 'admin@example.com', name: 'Admin User' }
    token = generate_jwt_token(user)
    session[:access_token] = token[:access_token]
    session[:refresh_token] = token[:refresh_token]
    session[:user_id] = user[:id]
    user
  end
  
  def generate_jwt_token(user)
    {
      access_token: JWT.encode(
        { sub: user[:id], exp: 1.hour.from_now.to_i },
        Rails.application.secret_key_base
      ),
      refresh_token: JWT.encode(
        { sub: user[:id], exp: 7.days.from_now.to_i },
        Rails.application.secret_key_base
      )
    }
  end
  
  def logout
    session[:access_token] = nil
    session[:refresh_token] = nil
    session[:user_id] = nil
  end
  
  def current_user_token
    session[:access_token]
  end
  
  def stub_current_user_authentication
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
      { id: 1, email: 'admin@example.com', name: 'Admin User' }
    )
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :controller
end