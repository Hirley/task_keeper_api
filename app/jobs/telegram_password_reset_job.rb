# frozen_string_literal: true

# Entrega o link de redefinição de senha por Telegram fora da requisição
# — ver TelegramPasswordResetsController#create, que responde na hora com
# a mesma mensagem genérica de sempre.
#
# Efeito colateral bem-vindo pro fluxo: como a chamada HTTP saiu da
# requisição, o tempo de resposta do formulário deixou de depender de o
# e-mail existir. Antes, um e-mail cadastrado com Chat ID esperava a API
# do Telegram responder e um e-mail desconhecido voltava na hora — a
# mensagem era a mesma nos dois casos, mas o cronômetro entregava a
# diferença que ela tenta esconder.
#
# O token do Devise é gerado aqui dentro (por
# Users::SendPasswordResetViaTelegram), não no controller: assim a
# validade do link (reset_password_within) conta a partir do envio, e não
# do momento em que o job entrou na fila.
class TelegramPasswordResetJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    usuario = User.find_by(id: user_id)
    # O usuário pode ter sido excluído, ou ter perdido o Chat ID, entre o
    # POST e o job rodar. Sem Chat ID não há pra onde enviar — e gerar o
    # token à toa invalidaria um link legítimo que ele tenha pedido por
    # e-mail nesse meio-tempo (o Devise guarda um token por usuário).
    return if usuario.nil? || usuario.telegram_chat_id.blank?

    Users::SendPasswordResetViaTelegram.call(user: usuario)
  end
end
