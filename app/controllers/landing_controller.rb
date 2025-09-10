class LandingController < ApplicationController
  layout 'landing'
  
  skip_before_action :authenticate_user!, only: [:index]
  
  def index
    # Redirect authenticated users to their dashboard instead of showing landing page
    redirect_to forms_path if user_signed_in?
  end
  
  private
  
  def skip_authorization?
    true
  end
end