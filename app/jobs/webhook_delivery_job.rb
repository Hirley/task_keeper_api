# frozen_string_literal: true

# Roda em background (adapter padrão do Rails, :async — não há
# Sidekiq/Solid Queue configurado neste projeto; jobs em andamento se
# perdem se o processo reiniciar, aceitável pro porte atual) pra não
# travar a request original no tempo de resposta de um serviço de
# terceiro. Ver WebhookDispatcher (quem enfileira) e WebhookDelivery
# (quem sabe fazer o POST de fato).
class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  def perform(subscription_id, event, payload)
    subscription = WebhookSubscription.find_by(id: subscription_id)
    WebhookDelivery.entregar(subscription, event, payload)
  end
end
