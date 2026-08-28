# frozen_string_literal: true

module Users
  # Mesma ideia de Users::SessionsController: só adiciona o throttle ao
  # "esqueci minha senha" por e-mail do Devise. Sem ele, o formulário
  # vira uma forma de disparar e-mails em massa pra caixa de uma vítima
  # (e de queimar a cota do provedor de envio) — o mesmo risco que
  # TelegramPasswordResetsController tem no lado do Telegram.
  class PasswordsController < Devise::PasswordsController
    include AuthThrottling

    throttle_auth_attempts only: :create, voltar_para: -> { new_user_password_path }
  end
end
