# Tela de Acessos (web): apenas o líder pode cadastrar novos usuários,
# alterar as permissões (papel líder/executor) e excluir usuários já
# existentes. Não há autocadastro — só o líder chega a esta tela (ver
# menu "Acessos" em app/views/layouts/application.html.haml e
# app/models/ability.rb).
class UsersController < ApplicationController
  before_action :authorize_manage_users!
  before_action :set_user, only: %i[edit update destroy]

  def index
    scope = User.order(:name)

    @q = params[:q]
    @role_filter = params[:role]
    @users = paginate(filter_users(scope))
    @name_suggestions = User.order(:name).limit(50).pluck(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "Usuário cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(permission_params)
      redirect_to users_path, notice: "Permissões atualizadas com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = Users::Destroy.call(user: @user, actor: current_user)

    if result.success?
      redirect_to users_path, notice: "Usuário excluído com sucesso."
    else
      redirect_to users_path, alert: result.error_message
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

  # Na edição não alteramos a senha por aqui (fluxo de "esqueci minha senha"
  # do Devise cobre isso); apenas dados cadastrais, a permissão (papel) e o
  # chat_id do Telegram usado para lembretes de atraso.
  def permission_params
    params.require(:user).permit(:name, :email, :role, :telegram_chat_id)
  end

  # Filtro usado na busca da tela de Acessos (campo com autocomplete por
  # nome/e-mail + select de permissão). Ambos são opcionais.
  def filter_users(scope)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      scope = scope.where("users.name LIKE ? OR users.email LIKE ?", term, term)
    end

    if params[:role].present? && User.roles.key?(params[:role])
      scope = scope.where(role: params[:role])
    end

    scope
  end
end
