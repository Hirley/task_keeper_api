# frozen_string_literal: true

# Usuário da aplicação. Não há autocadastro: apenas um líder ou admin pode
# criar novos usuários (ver Api::V1::UsersController), por isso o módulo
# :registerable do Devise não é habilitado aqui.
#
# Três papéis: executor (cadastra/visualiza demandas), líder (mais
# gerencia demandas de qualquer usuário e cadastra/altera acessos) e admin
# (mais dois privilégios exclusivos que nem o líder tem: telegram_chat_id
# — ver UsersController#user_params/#permission_params — e Webhooks de
# saída — ver app/models/ability.rb). Admin não substitui o líder: os dois
# continuam cadastrando usuários/alterando permissões igualmente.
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { executor: 0, lider: 1, admin: 2 }, default: :executor

  has_many :demandas, dependent: :restrict_with_error
  has_many :webhook_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :role, presence: true

  # Usado por TelegramNotifier para avisar o usuário sobre demandas
  # atrasadas (ver app/services/telegram_notifier.rb). É opcional — nem
  # todo usuário precisa configurar. Só o admin cadastra/edita esse valor
  # em /users (ver UsersController#telegram_chat_id_param); o próprio
  # usuário descobre o chat_id conversando com um bot como @userinfobot no
  # Telegram.
  validates :telegram_chat_id,
            format: { with: /\A-?\d+\z/, message: 'deve conter só números (o chat_id do Telegram)' },
            allow_blank: true

  def lider?
    role == 'lider'
  end

  def executor?
    role == 'executor'
  end

  def admin?
    role == 'admin'
  end

  # Líder e admin compartilham a mesma visão "gerencial" nas telas
  # (dashboard, Demandas, formulário de Acessos) — usado nos lugares que
  # antes só checavam lider?, agora que existe um terceiro papel acima.
  def lider_ou_admin?
    lider? || admin?
  end

  def role_label
    case role
    when 'admin' then 'admin'
    when 'lider' then 'líder'
    else 'executor'
    end
  end

  def role_badge_class
    case role
    when 'admin' then 'tk-badge-admin'
    when 'lider' then 'tk-badge-lider'
    else 'tk-badge-executor'
    end
  end

  # Whitelist exigida pelo Ransack (usado em UsersController#index e, via
  # associação "user", em DemandasController#index para ordenar por
  # responsável). Sem isso o Ransack recusa buscar/ordenar por qualquer
  # atributo, por segurança. "id" está aqui só para o desempate estável na
  # ordenação da tela de Acessos (ver UsersController::SORTABLE_COLUMNS).
  def self.ransackable_attributes(_auth_object = nil)
    %w[name email role id]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
