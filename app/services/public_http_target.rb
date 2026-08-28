# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'timeout'

# Resolve uma URL de terceiro e decide se ela pode ser acessada: precisa
# ser http(s), o host precisa resolver, e nenhum dos IPs pode cair numa
# faixa privada/local (proteção contra SSRF — o webhook não pode virar um
# jeito de fazer a aplicação bater num serviço interno da rede, como o
# Postgres do docker-compose ou o endpoint de metadados da nuvem).
#
# Devolve o IP escolhido junto com o resultado, e é isso que fecha a
# janela de DNS rebinding. Antes, WebhookSubscription checava os IPs no
# momento do cadastro e WebhookDelivery resolvia o host DE NOVO na hora
# do POST: um host com TTL curto passava na validação apontando pra um IP
# público e, minutos ou dias depois, resolvia pra 169.254.169.254 na hora
# da entrega. Como não havia corrida a ganhar (a entrega acontece quando
# uma demanda é concluída, muito depois do cadastro), bastava trocar o
# registro DNS com calma.
#
# Agora quem entrega chama este objeto imediatamente antes de conectar e
# usa +ip+ como endereço de destino (Net::HTTP#ipaddr=), mantendo o host
# original no cabeçalho Host e no certificado TLS. O IP verificado é o
# mesmo IP conectado — não sobra intervalo entre a checagem e o uso.
#
# Repare que o IP NÃO é gravado no banco: resolver a cada entrega é o que
# mantém endpoints legítimos funcionando quando o provedor troca de IP
# (o que é rotina em serviço de nuvem). O que se fixa é só o par
# "checagem + conexão" de uma entrega.
class PublicHttpTarget
  # DNS lento não pode segurar um worker web indefinidamente: a validação
  # de WebhookSubscription roda dentro do request de quem salvou o
  # formulário, e Resolv::DNS sozinho tentaria vários nameservers com
  # timeout generoso antes de desistir.
  RESOLVE_TIMEOUT = 5

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

  # +error_code+ em vez de mensagem pronta: quem chama decide o texto.
  # WebhookSubscription precisa de mensagem de formulário em português;
  # WebhookDelivery só quer registrar o motivo no log.
  Result = Struct.new(:uri, :ip, :error_code, keyword_init: true) do
    def success?
      error_code.nil?
    end
  end

  ERROR_CODES = %i[url_invalida host_nao_resolvido endereco_privado].freeze

  def self.resolve(url)
    new(url).resolve
  end

  def initialize(url)
    @url = url
  end

  def resolve
    uri = URI.parse(@url.to_s)
    return failure(:url_invalida) unless uri.is_a?(URI::HTTP) && uri.hostname.present?

    # #hostname e não #host: em URL com IPv6 literal (http://[::1]/) o
    # #host devolve "[::1]", com os colchetes, e nenhum resolvedor aceita
    # isso — o endereço cairia em "host não resolvido" em vez de ser
    # reconhecido e barrado como loopback.
    enderecos = resolver_enderecos(uri.hostname)
    return failure(:host_nao_resolvido) if enderecos.empty?

    # Basta UM endereço bloqueado pra recusar: um host pode publicar
    # registro A e AAAA ao mesmo tempo, e aceitar o par "público + privado"
    # deixaria a escolha de qual usar na mão da ordem de resolução.
    return failure(:endereco_privado) if enderecos.any? { |ip| bloqueado?(ip) }

    Result.new(uri: uri, ip: enderecos.first.to_s)
  rescue URI::InvalidURIError
    failure(:url_invalida)
  rescue Resolv::ResolvError, Timeout::Error
    failure(:host_nao_resolvido)
  end

  private

  def resolver_enderecos(host)
    Timeout.timeout(RESOLVE_TIMEOUT) do
      Resolv.getaddresses(host).map { |ip| IPAddr.new(ip) }
    end
  end

  # IPAddr#include? levanta IPAddr::AddressFamilyError ao comparar IPv4
  # com IPv6 (ex.: testar um endereço ::1 contra a faixa 127.0.0.0/8) —
  # por isso o "family == family" antes do include?.
  def bloqueado?(ip)
    BLOCKED_IP_RANGES.any? { |faixa| faixa.family == ip.family && faixa.include?(ip) }
  end

  def failure(error_code)
    Result.new(error_code: error_code)
  end
end
