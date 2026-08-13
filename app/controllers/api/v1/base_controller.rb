module Api
  module V1
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      rescue_from CanCan::AccessDenied do |exception|
        render json: { error: exception.message }, status: :forbidden
      end

      rescue_from ActiveRecord::RecordNotFound do |exception|
        render json: { error: exception.message }, status: :not_found
      end
    end
  end
end
