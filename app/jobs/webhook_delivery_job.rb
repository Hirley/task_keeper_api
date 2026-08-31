# frozen_string_literal: true

# Roda em background pra não travar a request original no tempo de
# resposta de um serviço de terceiro. Ver WebhookDispatcher (quem
# enfileira) e WebhookDelivery (quem sabe fazer o POST de fato).
#
# O adapter ainda é o padrão do Rails (:async), que guarda a fila na
# memória do processo web — jobs pendentes se perdem num restart, e as
# tentativas reagendadas abaixo também. Trocar por um backend persistente
# é assunto de outra issue; o retry aqui é útil de qualquer forma, porque
# a maioria das instabilidades de rede passa em segundos, muito antes de
# um deploy.
class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  TENTATIVAS = 5

  # Só WebhookDelivery::FalhaTemporaria reagenda. Uma recusa definitiva
  # (assinatura pausada, URL reprovada na checagem de SSRF, 4xx) volta
  # como `false` e encerra sem gastar tentativa — ver o contrato de
  # retorno documentado em WebhookDelivery#entregar.
  #
  # O bloco roda quando as tentativas acabam. Sem ele, a desistência
  # seria silenciosa, que é exatamente o problema que este retry veio
  # resolver — só que adiado para a quinta falha em vez da primeira.
  retry_on WebhookDelivery::FalhaTemporaria, wait: :polynomially_longer, attempts: TENTATIVAS do |job, erro|
    subscription_id, event = job.arguments

    Rails.logger.error(
      "[WebhookDeliveryJob] desisti de entregar \"#{event}\" pra assinatura #{subscription_id} " \
      "depois de #{TENTATIVAS} tentativas: #{erro.message}"
    )
  end

  def perform(subscription_id, event, payload)
    subscription = WebhookSubscription.find_by(id: subscription_id)
    WebhookDelivery.entregar(subscription, event, payload)
  end
end
