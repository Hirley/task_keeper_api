# Tela de Acessos (web): apenas o líder pode cadastrar novos usuários,
# alterar as permissões (papel líder/executor) e excluir usuários já
# existentes. Não há autocadastro — só o líder chega a esta tela (ver
# menu "Acessos" em app/views/layouts/application.html.haml e
# app/models/ability.rb).
class UsersController < ApplicationController
  before_action :authorize_manage_users!
  before_action :set_user, only: %i[edit update destroy]

  def index
    @users = User.order(:name)
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
    if @user == current_user
      redirect_to users_path, alert: "Você não pode excluir o seu próprio usuário." and return
    end

    if @user.demandas.exists?
      redirect_to users_path, alert: "Não é possível excluir #{@user.name}: existem demandas cadastradas por esse usuário." and return
    end

    @user.destroy
    redirect_to users_path, notice: "Usuário excluído com sucesso."
  end

  private

  def authorize_manage_users!
    authorize! :manage, User
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  # Na edição não alteramos a senha por aqui (fluxo de "esqueci minha senha"
  # do Devise cobre isso); apenas dados cadastrais e a permissão (papel).
  def permission_params
    params.require(:user).permit(:name, :email, :role)
  end
end
