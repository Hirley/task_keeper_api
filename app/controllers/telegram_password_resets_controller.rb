# frozen_string_literal: true

# Alternativa ao "esqueci minha senha" por e-mail (devise_for :users, ver
# config/routes.rb) pra quem já tem o Chat ID do Telegram cadastrado (ver
# User#telegram_chat_id) — reaproveita o mesmo token/link de redefinição
# do Devise, só que entregue por Telegram em vez de e-mail (ver
# Users::SendPasswordResetViaTelegram). Não exige login: é justamente pra
# quem está tentando recuperar o próprio acesso.
class TelegramPasswordResetsController < ApplicationController
  include AuthThrottling

  skip_before_action :authenticate_user!

  # A mensagem genérica abaixo não conta se o e-mail existe, mas sem
  # throttle o formulário ainda dá pra ser usado como metralhadora: quem
  # souber o e-mail de alguém com Chat ID cadastrado dispara mensagem de
  # redefinição no Telegram da vítima em looping.
  throttle_auth_attempts only: :create, voltar_para: -> { new_telegram_password_reset_path }

  # Sempre a mesma mensagem, exista ou não o e-mail e tenha ou não Chat ID
  # cadastrado — evita que alguém descubra, por tentativa e erro, quais
  # e-mails estão cadastrados no sistema (mesma postura "paranoica" do
  # Devise — ver devise.passwords.send_paranoid_instructions em
  # config/locales/pt-BR.yml).
  GENERIC_NOTICE = 'Se o e-mail informado tiver um Chat ID do Telegram cadastrado, você vai receber uma ' \
                   'mensagem com instruções para redefinir sua senha.'

  def new; end

  # O envio é enfileirado (ver TelegramPasswordResetJob): a chamada à API
  # do Telegram acontecia aqui dentro, prendendo um worker do Puma no
  # tempo de resposta de um serviço de terceiro — numa tela pública, que
  # qualquer um alcança sem login.
  #
  # Isso melhora a resposta genérica em vez de enfraquecê-la: antes, o
  # e-mail cadastrado esperava o Telegram responder e o desconhecido
  # voltava na hora, então o cronômetro entregava o que a mensagem tenta
  # esconder. Agora os dois caminhos fazem um SELECT, e um deles um
  # INSERT na fila.
  #
  # Descartado enfileirar sempre, passando o e-mail digitado pro job (que
  # deixaria a resposta rigorosamente constante): guardaria e-mail
  # arbitrário de visitante anônimo na tabela de jobs, e deixaria o
  # formulário encher a fila. O throttle por IP e por e-mail
  # (AuthThrottling) já é o que barra o uso do formulário como
  # metralhadora.
  def create
    usuario = User.find_by(email: params[:email].to_s.strip.downcase)
    TelegramPasswordResetJob.perform_later(usuario.id) if usuario&.telegram_chat_id.present?

    redirect_to new_telegram_password_reset_path, notice: GENERIC_NOTICE
  end
end
