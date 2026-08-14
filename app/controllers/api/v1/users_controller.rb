module Api
  module V1
    # Apenas o líder pode listar/cadastrar/excluir usuários. Não há autocadastro.
    class UsersController < BaseController
      before_action :authorize_manage_users!
      before_action :set_user, only: %i[show destroy]

      # GET /api/v1/users
      def index
        @users = User.order(:name)
        render json: @users, except: [:encrypted_password, :reset_password_token]
      end

      # GET /api/v1/users/:id
      def show
        render json: @user, except: [:encrypted_password, :reset_password_token]
      end

      # POST /api/v1/users
      def create
        @user = User.new(user_params)

        if @user.save
          render json: @user, except: [:encrypted_password, :reset_password_token], status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        result = Users::Destroy.call(user: @user, actor: current_user)

        if result.success?
          head :no_content
        else
          render json: { error: result.error_message }, status: :unprocessable_entity
        end
      end

      private

      def authorize_manage_users!
        authorize! :manage, User
      end

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :telegram_chat_id)
      end
    end
  end
end
