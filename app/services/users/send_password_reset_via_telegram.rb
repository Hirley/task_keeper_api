# frozen_string_literal: true

module Users
  # Gera um token de redefinição de senha do Devise (o mesmo mecanismo do
  # :recoverable — ver User#reset_password) e entrega o link por Telegram
  # em vez de e-mail, usando o Chat ID que o admin já cadastrou (ver
  # User#telegram_chat_id). Usado por TelegramPasswordResetsController.
  class SendPasswordResetViaTelegram
    def self.call(user:, telegram_notifier: TelegramNotifier.new)
      new(user: user, telegram_notifier: telegram_notifier).call
    end

    def initialize(user:, telegram_notifier:)
      @user = user
      @telegram_notifier = telegram_notifier
    end

    def call
      raw_token = @user.generate_reset_password_token
      @telegram_notifier.enviar_redefinicao_senha(@user, reset_url(raw_token))
    end

    private

    def reset_url(raw_token)
      host_options = Rails.application.config.action_mailer.default_url_options
      Rails.application.routes.url_helpers.edit_user_password_url(reset_password_token: raw_token, **host_options)
    end
  end
end
