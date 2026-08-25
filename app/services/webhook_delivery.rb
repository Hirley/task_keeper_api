# frozen_string_literal: true

require 'net/http'
require 'json'

# Faz o POST de fato de um evento de webhook — usado por WebhookDeliveryJob.
# Separado do job (que só busca a assinatura e enfileira/desenfileira) pra
# poder testar a montagem do payload e o tratamento de erro sem depender
# do ActiveJob, mesmo padrão de TelegramNotifier (+transport+ injetável
# evita depender de uma gem de mock de rede — o Gemfile não tem
# WebMock/VCR — e evita qualquer chamada de rede real nos testes).
class WebhookDelivery
  DEFAULT_TRANSPORT = lambda do |uri, body|
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5) do |http|
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = body
      http.request(request)
    end
  end

  def self.entregar(subscription, event, payload)
    new.entregar(subscription, event, payload)
  end

  def initialize(transport: DEFAULT_TRANSPORT)
    @transport = transport
  end

  # Não levanta exceção pra fora — um endpoint de terceiro fora do ar,
  # lento ou respondendo erro não pode derrubar o job (nem, se algum dia a
  # entrega virar síncrona, a request que originou o evento). Loga e
  # retorna false; não há retry (fora do escopo deste MVP — ver issue de
  # webhooks de saída no board).
  def entregar(subscription, event, payload)
    return false unless subscription&.active?

    uri = URI(subscription.url)
    body = { event: event, occurred_at: Time.current.iso8601, data: payload }.to_json
    response = @transport.call(uri, body)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.warn("[WebhookDelivery] falha ao entregar \"#{event}\" pra #{subscription&.url}: #{e.class} #{e.message}")
    false
  end
end
