# frozen_string_literal: true

# Ponto de entrada único pra disparar um evento de domínio pros webhooks
# cadastrados (ver WebhookSubscription). Quem gera o evento (Demanda,
# RelatoriosController) só chama .dispatch com um Hash já pronto — não
# precisa saber nada sobre quantas assinaturas existem nem como a entrega
# funciona.
#
# +payload+ precisa ser um Hash simples (serializável em JSON), não um
# registro do ActiveRecord: o job de entrega roda de forma assíncrona (ver
# WebhookDeliveryJob), e pro evento "demanda_excluida" o registro já não
# existe mais no banco no momento em que o job de fato roda — só o Hash
# montado antes da exclusão sobrevive.
class WebhookDispatcher
  def self.dispatch(event, payload)
    new.dispatch(event, payload)
  end

  def dispatch(event, payload)
    WebhookSubscription.active.for_event(event).find_each do |subscription|
      WebhookDeliveryJob.perform_later(subscription.id, event, payload)
    end
  end
end
