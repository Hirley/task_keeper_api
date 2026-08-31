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
  # Única exceção que escapa daqui de propósito. É o sinal que faz
  # WebhookDeliveryJob reagendar a entrega (ver o retry_on lá).
  class FalhaTemporaria < StandardError; end

  # Erros de rede que costumam passar sozinhos: o endpoint pode estar
  # reiniciando, o DNS oscilando, a rota caindo por um instante.
  #
  # Erro de TLS fica de fora de propósito. Certificado inválido, expirado
  # ou com nome errado é configuração do outro lado — repetir cinco vezes
  # não conserta, só adia o diagnóstico e mantém uma assinatura quebrada
  # parecendo viva.
  ERROS_TEMPORARIOS = [
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
    Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, EOFError, SocketError
  ].freeze

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

  # O retorno é o que decide se o job tenta de novo:
  #
  #   * +true+ — entregue (2xx);
  #   * +false+ — recusa definitiva: assinatura inexistente ou pausada,
  #     URL reprovada na checagem de SSRF, ou resposta 4xx. Tentar de novo
  #     não mudaria nada, então o job encerra sem gastar tentativa;
  #   * +FalhaTemporaria+ — erro de rede, 429 ou 5xx.
  #
  # Antes, TODA falha virava +false+ e o ActiveJob dava a entrega por
  # concluída: um endpoint fora do ar sumia com um aviso no log e ninguém
  # reprocessava. A distinção acima existe pra que só o caso que vale a
  # pena repetir chegue ao retry_on.
  def entregar(subscription, event, payload)
    return false unless subscription&.active?

    # Resolve e valida AQUI, imediatamente antes de conectar — e não
    # confia no que foi validado lá atrás, no cadastro. É esta chamada
    # que é a proteção de SSRF; a validação do modelo é só o aviso na
    # tela. Ver PublicHttpTarget.
    alvo = PublicHttpTarget.resolve(subscription.url)

    unless alvo.success?
      registrar_recusa(subscription, event, alvo.error_code)
      return false
    end

    body = { event: event, occurred_at: Time.current.iso8601, data: payload }.to_json
    entregue?(subscription, event, @transport.call(alvo.uri, body, alvo.ip))
  rescue FalhaTemporaria
    # Precisa vir ANTES do rescue de StandardError: FalhaTemporaria herda
    # dele, e sem esta cláusula a exceção levantada por #entregue? seria
    # engolida logo abaixo — virando de novo o `false` silencioso que
    # esta classe deixou de produzir.
    raise
  rescue *ERROS_TEMPORARIOS => e
    raise FalhaTemporaria, "#{subscription.url}: #{e.class} #{e.message}"
  rescue StandardError => e
    # Erro inesperado aqui é bug nosso, não instabilidade do outro lado.
    # Repetir não conserta e só atrasa o diagnóstico — loga alto e
    # encerra, sem consumir tentativa.
    Rails.logger.error(
      "[WebhookDelivery] erro inesperado ao entregar \"#{event}\" pra #{subscription&.url}: #{e.class} #{e.message}"
    )
    false
  end

  private

  def entregue?(subscription, event, response)
    return true if response.is_a?(Net::HTTPSuccess)
    raise FalhaTemporaria, "#{subscription.url} respondeu #{response.class}" if temporaria?(response)

    Rails.logger.warn(
      "[WebhookDelivery] entrega de \"#{event}\" pra #{subscription.url} recusada com #{response.class}"
    )
    false
  end

  # 5xx é problema do servidor do outro lado; 429 é ele pedindo pra
  # esperar. Os dois merecem outra tentativa. Um 4xx qualquer, não: o
  # payload ou a rota é que estão errados, e repetir só gera ruído.
  def temporaria?(response)
    response.is_a?(Net::HTTPServerError) || response.is_a?(Net::HTTPTooManyRequests)
  end

  # Só registra o motivo — quem chama é que decide desistir da entrega. O
  # `return false` fica lá em cima, visível junto do `unless`, em vez de
  # escondido no fim de um método cujo nome não deixa claro que ele
  # também define o valor de retorno de #entregar.
  def registrar_recusa(subscription, event, error_code)
    Rails.logger.warn(
      "[WebhookDelivery] entrega de \"#{event}\" pra #{subscription.url} recusada na resolução: #{error_code}"
    )
  end
end
