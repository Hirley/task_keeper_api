# frozen_string_literal: true

# Alternativa ao "esqueci minha senha" por e-mail (devise_for :users, ver
# config/routes.rb) pra quem já tem o Chat ID do Telegram cadastrado (ver
# User#telegram_chat_id) — reaproveita o mesmo token/link de redefinição
# do Devise, só que entregue por Telegram em vez de e-mail (ver
# Users::SendPasswordResetViaTelegram). Não exige login: é justamente pra
# quem está tentando recuperar o próprio acesso.
class TelegramPasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!

  # Sempre a mesma mensagem, exista ou não o e-mail e tenha ou não Chat ID
  # cadastrado — evita que alguém descubra, por tentativa e erro, quais
  # e-mails estão cadastrados no sistema (mesma postura "paranoica" do
  # Devise — ver devise.passwords.send_paranoid_instructions em
  # config/locales/pt-BR.yml).
  GENERIC_NOTICE = 'Se o e-mail informado tiver um Chat ID do Telegram cadastrado, você vai receber uma ' \
                   'mensagem com instruções para redefinir sua senha.'

  def new; end

  def create
    usuario = User.find_by(email: params[:email].to_s.strip.downcase)
    Users::SendPasswordResetViaTelegram.call(user: usuario) if usuario&.telegram_chat_id.present?

    redirect_to new_telegram_password_reset_path, notice: GENERIC_NOTICE
  end
end
