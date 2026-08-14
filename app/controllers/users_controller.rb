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
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :telegram_chat_id)
  end

  # Na edição não alteramos a senha por aqui (fluxo de "esqueci minha senha"
  # do Devise cobre isso); apenas dados cadastrais, a permissão (papel) e o
  # chat_id do Telegram usado para lembretes de atraso.
  def permission_params
    params.require(:user).permit(:name, :email, :role, :telegram_chat_id)
  end

  # Filtro usado na busca da tela de Acessos (campo com autocomplete por
  # nome/e-mail + select de permissão). Ambos são opcionais. Ransack é usado
  # só como mecanismo interno de query — o contrato externo continua sendo
  # os mesmos params simples de sempre (q, role), não a sintaxe nativa do
  # Ransack. "name_or_email_cont" é a convenção do Ransack para combinar
  # duas condições com OR a partir de um único termo de busca (equivalente
  # ao antigo "users.name LIKE ? OR users.email LIKE ?"). A ordenação por
  # nome continua fixa (.order(:name) em #index), não é ajustável por quem
  # acessa a tela, então não passamos "sorts" para o Ransack aqui.
  def filter_users(scope)
    scope.ransack(name_or_email_cont: params[:q].presence, role_eq: normalized_role_filter).result
  end

  # Mesma validação de antes: só aplica o filtro de permissão se for uma
  # chave válida do enum, para não deixar o Ransack tentar comparar com um
  # valor arbitrário vindo da URL.
  def normalized_role_filter
    return nil unless params[:role].present? && User.roles.key?(params[:role])

    params[:role]
  end
end
