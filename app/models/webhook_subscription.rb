# frozen_string_literal: true

# Cadastro de webhook de saída (líder configura em /webhooks) — quando um
# dos eventos escolhidos acontece, WebhookDispatcher enfileira um POST em
# +url+ com o payload do evento (ver app/services/webhook_dispatcher.rb,
# app/jobs/webhook_delivery_job.rb). Serve tanto pra notificar um canal de
# chat (Slack/Teams/Discord, via um webhook incoming deles) quanto pra
# disparar uma automação no-code (n8n/Knime) — o mecanismo é o mesmo, só
# muda quem recebe o POST.
class WebhookSubscription < ApplicationRecord
  EVENTS = %w[demanda_criada demanda_concluida demanda_excluida relatorio_gerado].freeze

  # Mensagem de formulário pra cada motivo de recusa devolvido pelo
  # PublicHttpTarget (que conhece as faixas de IP bloqueadas e faz a
  # resolução — ver app/services/public_http_target.rb).
  ERROS_DE_URL = {
    url_invalida: 'deve ser uma URL http:// ou https:// válida',
    host_nao_resolvido: 'host não pôde ser resolvido',
    endereco_privado: 'não pode apontar pra um endereço de rede privado/local'
  }.freeze

  belongs_to :user

  validates :url, presence: true
  validates :events, presence: true
  validate :validar_eventos_conhecidos
  validate :validar_url_publica_e_resolvivel

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { where('? = ANY(events)', event) }

  private

  def validar_eventos_conhecidos
    desconhecidos = Array(events) - EVENTS
    return if desconhecidos.empty?

    errors.add(:events, "contém evento(s) desconhecido(s): #{desconhecidos.join(', ')}")
  end

  # Roda no cadastro/edição pra dar erro no formulário na hora, enquanto o
  # líder ainda está na tela. NÃO é a proteção de SSRF em si: o host pode
  # passar por aqui hoje e resolver pra um IP privado na hora da entrega,
  # dias depois. Quem de fato protege é WebhookDelivery, que refaz esta
  # mesma checagem imediatamente antes de conectar — ver o comentário em
  # PublicHttpTarget sobre DNS rebinding.
  def validar_url_publica_e_resolvivel
    return if url.blank?

    resultado = PublicHttpTarget.resolve(url)
    return if resultado.success?

    errors.add(:url, ERROS_DE_URL.fetch(resultado.error_code))
  end
end
