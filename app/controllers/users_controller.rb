# frozen_string_literal: true

# Tela de Acessos (web): apenas o líder pode cadastrar novos usuários,
# alterar as permissões (papel líder/executor) e excluir usuários já
# existentes. Não há autocadastro — só o líder chega a esta tela (ver
# menu "Acessos" em app/views/layouts/application.html.haml e
# app/models/ability.rb).
class UsersController < ApplicationController
  before_action :authorize_manage_users!
  before_action :set_user, only: %i[edit update destroy]

  # Colunas que podem ser usadas para ordenar a listagem (whitelist — nunca
  # interpolar params[:sort] direto numa query). Mesma convenção usada em
  # DemandasController::SORTABLE_COLUMNS.
  SORTABLE_COLUMNS = {
    'name' => 'name',
    'email' => 'email',
    'role' => 'role'
  }.freeze

  def index
    scope = User.all

    @q = params[:q]
    @role_filter_keys = normalized_role_filter_keys
    @role_filter = @role_filter_keys.map { |role| User.roles[role] }
    @sort = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : 'name'
    # Default "asc" (não "desc" como em Demandas) pra preservar o
    # comportamento antigo, que era sempre `.order(:name)` ascendente.
    @direction = params[:direction] == 'desc' ? 'desc' : 'asc'

    @users = paginate(filter_users(scope))
    @name_suggestions = User.order(:name).limit(50).pluck(:name)
  end

  def new
    @user = User.new
  end

  def edit; end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: 'Usuário cadastrado com sucesso.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @user.update(permission_params)
      redirect_to users_path, notice: 'Permissões atualizadas com sucesso.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    result = Users::Destroy.call(user: @user, actor: current_user)

    if result.success?
      redirect_to users_path, notice: 'Usuário excluído com sucesso.'
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
  # nome/e-mail + select de permissão). Ambos são opcionais. Ransack é usado
  # só como mecanismo interno de query — o contrato externo continua sendo
  # os mesmos params simples de sempre (q, role, sort, direction), não a
  # sintaxe nativa do Ransack. "name_or_email_cont_any" combina duas coisas:
  # "name_or_email" (convenção do Ransack pra combinar duas condições com
  # OR, equivalente a "users.name LIKE ? OR users.email LIKE ?") e
  # "_cont_any" (aceita vários termos, um por linha do array, também
  # combinados com OR — ver #title_terms em DemandasController pro mesmo
  # padrão). "id" no fim mantém o desempate estável.
  def filter_users(scope)
    ransack_query = scope.ransack(name_or_email_cont_any: q_terms.presence, role_in: @role_filter.presence)
    ransack_query.sorts = ["#{SORTABLE_COLUMNS.fetch(@sort)} #{@direction}", "id #{@direction}"]
    ransack_query.result
  end

  # Mesma validação de antes: só deixa passar chaves válidas do enum.
  # Aceita um valor único (role=x, formato antigo) ou vários
  # (role[]=x&role[]=y, dos checkboxes da tela) — ver
  # DemandasController#normalized_status_filter_keys pro mesmo padrão.
  #
  # Devolve as chaves do enum (strings, ex.: "lider") — @role_filter
  # (acima, em #index) traduz pro valor inteiro que o Ransack precisa; as
  # chaves em si são o que a view usa pra marcar quais checkboxes ficam
  # pré-selecionados.
  def normalized_role_filter_keys
    Array(params[:role]).select { |role| User.roles.key?(role) }
  end

  # Mesma ideia de DemandasController#title_terms: divide a busca por
  # nome/e-mail em vários termos separados por vírgula.
  def q_terms
    @q.to_s.split(',').map(&:strip).compact_blank
  end
end
