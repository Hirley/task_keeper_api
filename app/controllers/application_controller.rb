class ApplicationController < ActionController::Base
  include Paginatable

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
      format.any  { render plain: exception.message, status: :forbidden }
    end
  end
end
