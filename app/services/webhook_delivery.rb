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
  # +ipaddr+ é o endereço já verificado por PublicHttpTarget. Passar ele
  # pro Net::HTTP faz a conexão ir direto nesse IP, sem resolver o host de
  # novo — é o que impede que o DNS mude entre a checagem e a conexão
  # (DNS rebinding). O primeiro argumento continua sendo o host, então
  # cabeçalho Host, SNI e validação do certificado TLS seguem sendo
  # feitos contra o nome original, como devem.
  DEFAULT_TRANSPORT = lambda do |uri, body, ipaddr|
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', ipaddr: ipaddr,
                                            open_timeout: 5, read_timeout: 5) do |http|
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

    # Resolve e valida AQUI, imediatamente antes de conectar — e não
    # confia no que foi validado lá atrás, no cadastro. É esta chamada
    # que é a proteção de SSRF; a validação do modelo é só o aviso na
    # tela. Ver PublicHttpTarget.
    alvo = PublicHttpTarget.resolve(subscription.url)
    return recusar(subscription, event, alvo.error_code) unless alvo.success?

    body = { event: event, occurred_at: Time.current.iso8601, data: payload }.to_json
    response = @transport.call(alvo.uri, body, alvo.ip)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.warn("[WebhookDelivery] falha ao entregar \"#{event}\" pra #{subscription&.url}: #{e.class} #{e.message}")
    false
  end

  private

  def recusar(subscription, event, error_code)
    Rails.logger.warn(
      "[WebhookDelivery] entrega de \"#{event}\" pra #{subscription.url} recusada na resolução: #{error_code}"
    )
    false
  end
end
