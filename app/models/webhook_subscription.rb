# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

# Cadastro de webhook de saída (líder configura em /webhooks) — quando um
# dos eventos escolhidos acontece, WebhookDispatcher enfileira um POST em
# +url+ com o payload do evento (ver app/services/webhook_dispatcher.rb,
# app/jobs/webhook_delivery_job.rb). Serve tanto pra notificar um canal de
# chat (Slack/Teams/Discord, via um webhook incoming deles) quanto pra
# disparar uma automação no-code (n8n/Knime) — o mecanismo é o mesmo, só
# muda quem recebe o POST.
class WebhookSubscription < ApplicationRecord
  EVENTS = %w[demanda_criada demanda_concluida demanda_excluida relatorio_gerado].freeze

  # Faixas de IP privadas/locais — bloqueadas na validação da URL pra
  # reduzir o risco de SSRF (o líder poderia, sem querer ou não, apontar o
  # webhook pra um serviço interno da rede, ex.: o próprio Postgres do
  # docker-compose). Resolve o host no momento do cadastro/edição; não
  # protege contra DNS rebinding (o mesmo host podendo resolver pra um IP
  # diferente na hora da entrega de fato, minutos/dias depois) — mitigar
  # isso exigiria fixar o IP resolvido aqui e usá-lo direto na entrega,
  # fora do escopo deste MVP.
  BLOCKED_IP_RANGES = [
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('169.254.0.0/16'),
    IPAddr.new('::1/128'),
    IPAddr.new('fc00::/7'),
    IPAddr.new('fe80::/10')
  ].freeze

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

  def validar_url_publica_e_resolvivel
    return if url.blank?

    uri = URI.parse(url)
    return errors.add(:url, 'deve ser uma URL http:// ou https:// válida') unless uri.is_a?(URI::HTTP) && uri.host

    enderecos = Resolv.getaddresses(uri.host).map { |ip| IPAddr.new(ip) }
    return errors.add(:url, 'host não pôde ser resolvido') if enderecos.empty?

    return unless enderecos.any? { |ip| endereco_bloqueado?(ip) }

    errors.add(:url, 'não pode apontar pra um endereço de rede privado/local')
  rescue URI::InvalidURIError
    errors.add(:url, 'deve ser uma URL http:// ou https:// válida')
  rescue Resolv::ResolvError
    errors.add(:url, 'host não pôde ser resolvido')
  end

  # IPAddr#include? levanta IPAddr::AddressFamilyError ao comparar IPv4
  # com IPv6 (ex.: testar um endereço ::1 contra a faixa 127.0.0.0/8) —
  # por isso o "family == family" antes do include?, já que o host pode
  # ter registro A e AAAA ao mesmo tempo.
  def endereco_bloqueado?(ip)
    BLOCKED_IP_RANGES.any? { |bloqueada| bloqueada.family == ip.family && bloqueada.include?(ip) }
  end
end
