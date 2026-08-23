# frozen_string_literal: true

# Usuário da aplicação. Não há autocadastro: apenas um líder pode criar
# novos usuários (ver Api::V1::UsersController), por isso o módulo
# :registerable do Devise não é habilitado aqui.
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { executor: 0, lider: 1 }, default: :executor

  has_many :demandas, dependent: :restrict_with_error
  has_many :webhook_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :role, presence: true

  # Usado por TelegramNotifier para avisar o usuário sobre demandas
  # atrasadas (ver app/services/telegram_notifier.rb). É opcional — nem
  # todo usuário precisa configurar. O líder cadastra/edita esse valor em
  # /users; o próprio usuário descobre o chat_id conversando com um bot
  # como @userinfobot no Telegram.
  validates :telegram_chat_id,
            format: { with: /\A-?\d+\z/, message: 'deve conter só números (o chat_id do Telegram)' },
            allow_blank: true

  def lider?
    role == 'lider'
  end

  def executor?
    role == 'executor'
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
