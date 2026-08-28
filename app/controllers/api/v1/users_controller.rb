# frozen_string_literal: true

module Api
  module V1
    # Líder e admin podem listar/cadastrar/excluir usuários — mas só admin
    # define telegram_chat_id (ver #user_params). Não há autocadastro.
    class UsersController < BaseController
      # Allowlist, e não blocklist. Antes daqui a serialização era
      # `except: %i[encrypted_password reset_password_token]`, o que
      # invertia o ônus da prova: toda coluna nova da tabela users nascia
      # publicada na API, e só deixava de ser se alguém lembrasse de
      # adicioná-la à lista de exclusão. Foi assim que telegram_chat_id
      # passou a ser devolvido a qualquer líder, sendo que só admin pode
      # gravá-lo. Com allowlist a conta se inverte: coluna nova nasce
      # escondida e só aparece se este arquivo disser que deve aparecer.
      #
      # Fora daqui, de propósito: tour_completed_at (estado de UI, não
      # interessa a um cliente de API) e todo o material do Devise
      # (encrypted_password, reset_password_token, reset_password_sent_at,
      # remember_created_at).
      CAMPOS_PUBLICOS = %i[id name email role must_change_password created_at updated_at].freeze

      before_action :authorize_manage_users!
      before_action :set_user, only: %i[show destroy]

      # GET /api/v1/users
      def index
        @users = User.order(:name)
        render json: @users, only: campos_serializados
      end

      # GET /api/v1/users/:id
      def show
        render json: @user, only: campos_serializados
      end

      # POST /api/v1/users
      def create
        @user = User.new(user_params)
        # Ver User#validar_atribuicao_de_papel: sem isso a API seria a
        # porta dos fundos pra um líder cadastrar um admin.
        @user.ator = current_user

        if @user.save
          render json: @user, only: campos_serializados, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        result = Users::Destroy.call(user: @user, actor: current_user)

        if result.success?
          head :no_content
        else
          render json: { error: result.error_message }, status: :unprocessable_content
        end
      end

      private

      def authorize_manage_users!
        authorize! :manage, User
      end

      def set_user
        @user = User.find(params[:id])
      end

      # A mesma regra de #user_params, na direção da leitura: telegram_chat_id
      # é privilégio de admin, então quem não pode gravá-lo também não o lê.
      # As duas pontas saem do mesmo #telegram_chat_id_param de propósito —
      # assim não dá pra mudar o privilégio de escrita e esquecer a leitura,
      # nem sobra o resultado esquisito de um admin cadastrar pela API um
      # valor que a própria API nunca devolve.
      def campos_serializados
        CAMPOS_PUBLICOS + telegram_chat_id_param
      end

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, *telegram_chat_id_param)
      end

      def telegram_chat_id_param
        current_user.admin? ? [:telegram_chat_id] : []
      end
    end
  end
end
