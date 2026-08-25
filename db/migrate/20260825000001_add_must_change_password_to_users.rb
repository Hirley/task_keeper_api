# frozen_string_literal: true

class AddMustChangePasswordToUsers < ActiveRecord::Migration[8.1]
  def change
    # true por padrão: todo usuário novo entra com a senha provisória
    # cadastrada pelo líder/admin (ver UsersController#create) e precisa
    # cadastrar a própria senha no primeiro acesso (ver
    # ApplicationController#exigir_troca_de_senha! e DefinirSenhaController).
    # Vira false assim que o usuário define a própria senha — no primeiro
    # acesso ou depois, via "esqueci minha senha" por e-mail/Telegram (ver
    # User#reset_password).
    add_column :users, :must_change_password, :boolean, null: false, default: true
  end
end
