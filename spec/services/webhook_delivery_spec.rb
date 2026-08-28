# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

RSpec.describe WebhookDelivery do
  # Mesmo padrão de spec/services/telegram_notifier_spec.rb: dublê simples
  # do transporte HTTP, sem gem de mock de rede e sem chamada de rede real.
  subject(:delivery) { described_class.new(transport: transport) }

  let(:chamadas) { [] }
  let(:resposta_sucesso) { Net::HTTPOK.allocate }
  let(:resposta_falha) { Net::HTTPBadRequest.allocate }
  let(:transport) do
    lambda { |uri, body, ipaddr|
      chamadas << { uri: uri, body: body, ipaddr: ipaddr }
      resposta_sucesso
    }
  end

  # IP literal em vez de hostname, mesma razão da factory: Resolv
  # reconhece um IP literal sem consultar DNS de verdade, então o teste
  # não depende de rede externa. 8.8.8.8 é público, logo passa na
  # verificação de PublicHttpTarget.
  let(:subscription) { build_stubbed(:webhook_subscription, url: 'https://8.8.8.8/in') }

  describe '#entregar' do
    it 'faz POST na URL da assinatura com o evento e o payload' do
      delivery.entregar(subscription, 'demanda_criada', { id: 1, title: 'Revisar contrato' })

      expect(chamadas.size).to eq(1)
      expect(chamadas.first[:uri].to_s).to eq('https://8.8.8.8/in')

      corpo = JSON.parse(chamadas.first[:body])
      expect(corpo['event']).to eq('demanda_criada')
      expect(corpo['data']).to eq({ 'id' => 1, 'title' => 'Revisar contrato' })
      expect(corpo['occurred_at']).to be_present
    end

    it 'retorna true quando o endpoint responde com sucesso' do
      expect(delivery.entregar(subscription, 'demanda_criada', {})).to be true
    end

    it 'retorna false quando o endpoint responde com erro' do
      delivery_com_falha = described_class.new(transport: ->(_uri, _body, _ip) { resposta_falha })

      expect(delivery_com_falha.entregar(subscription, 'demanda_criada', {})).to be false
    end

    it 'não envia nada e retorna false pra uma assinatura pausada (active: false)' do
      inativa = build_stubbed(:webhook_subscription, :inativo)

      expect(delivery.entregar(inativa, 'demanda_criada', {})).to be false
      expect(chamadas).to be_empty
    end

    it 'não envia nada e retorna false quando a assinatura é nil (ex.: foi excluída antes do job rodar)' do
      expect(delivery.entregar(nil, 'demanda_criada', {})).to be false
      expect(chamadas).to be_empty
    end

    it 'não propaga exceção se o transporte falhar (ex.: endpoint fora do ar) e retorna false' do
      delivery_com_erro = described_class.new(transport: ->(_uri, _body, _ip) { raise SocketError, 'falha de rede' })

      expect(delivery_com_erro.entregar(subscription, 'demanda_criada', {})).to be false
    end

    # Ver PublicHttpTarget: a validação do cadastro sozinha não segura DNS
    # rebinding, porque o host pode mudar de IP depois de salvo. Por isso
    # a checagem é refeita aqui, na hora de conectar.
    describe 'proteção contra SSRF na hora da entrega' do
      it 'recusa a entrega quando a URL salva aponta pra um endereço privado' do
        # build_stubbed não roda validação — é exatamente a assinatura que
        # passou na checagem no cadastro e só depois virou interna.
        interna = build_stubbed(:webhook_subscription, url: 'http://169.254.169.254/latest/meta-data')

        expect(delivery.entregar(interna, 'demanda_criada', {})).to be false
        expect(chamadas).to be_empty
      end

      it 'recusa a entrega pra loopback' do
        loopback = build_stubbed(:webhook_subscription, url: 'http://127.0.0.1/hook')

        expect(delivery.entregar(loopback, 'demanda_criada', {})).to be false
        expect(chamadas).to be_empty
      end

      it 'entrega no IP já verificado, em vez de deixar o Net::HTTP resolver o host de novo' do
        delivery.entregar(subscription, 'demanda_criada', {})

        expect(chamadas.first[:ipaddr]).to eq('8.8.8.8')
      end
    end
  end

  describe '.entregar' do
    it 'delega para uma instância nova' do
      expect(described_class.entregar(nil, 'demanda_criada', {})).to be false
    end
  end
end
