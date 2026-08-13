# Usuário da aplicação. Não há autocadastro: apenas um líder pode criar
# novos usuários (ver Api::V1::UsersController), por isso o módulo
# :registerable do Devise não é habilitado aqui.
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { executor: 0, lider: 1 }, default: :executor

  has_many :demandas, dependent: :restrict_with_error

  validates :name, presence: true
  validates :role, presence: true

  def lider?
    role == "lider"
  end

  def executor?
    role == "executor"
  end
end
