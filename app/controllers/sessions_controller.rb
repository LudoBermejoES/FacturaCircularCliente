class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  
  def new
    redirect_to dashboard_path if logged_in?
  end
  
  def create
    begin
      auth_response = AuthService.login(
        params[:email],
        params[:password]
      )
      
      if auth_response
        store_session(auth_response)
        redirect_to dashboard_path, notice: 'Successfully logged in!'
      else
        flash.now[:alert] = 'Invalid email or password'
        render :new, status: :unprocessable_entity
      end
    rescue ApiService::AuthenticationError => e
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      flash.now[:alert] = 'Unable to connect to the server. Please try again later.'
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    begin
      AuthService.logout(current_token) if current_token
    rescue => e
      Rails.logger.error "Logout error: #{e.message}"
    ensure
      clear_session
      redirect_to login_path, notice: 'Successfully logged out!'
    end
  end
  
  private
  
  def store_session(auth_response)
    session[:access_token] = auth_response[:access_token]
    session[:refresh_token] = auth_response[:refresh_token]
    session[:user_id] = auth_response[:user][:id] if auth_response[:user]
    session[:user_email] = auth_response[:user][:email] if auth_response[:user]
    session[:user_name] = auth_response[:user][:name] if auth_response[:user]
  end
  
  def clear_session
    session[:access_token] = nil
    session[:refresh_token] = nil
    session[:user_id] = nil
    session[:user_email] = nil
    session[:user_name] = nil
    reset_session
  end
end