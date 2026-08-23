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
    lambda { |uri, body|
      chamadas << { uri: uri, body: body }
      resposta_sucesso
    }
  end

  let(:subscription) { build_stubbed(:webhook_subscription, url: 'https://hooks.example.com/in') }

  describe '#entregar' do
    it 'faz POST na URL da assinatura com o evento e o payload' do
      delivery.entregar(subscription, 'demanda_criada', { id: 1, title: 'Revisar contrato' })

      expect(chamadas.size).to eq(1)
      expect(chamadas.first[:uri].to_s).to eq('https://hooks.example.com/in')

      corpo = JSON.parse(chamadas.first[:body])
      expect(corpo['event']).to eq('demanda_criada')
      expect(corpo['data']).to eq({ 'id' => 1, 'title' => 'Revisar contrato' })
      expect(corpo['occurred_at']).to be_present
    end

    it 'retorna true quando o endpoint responde com sucesso' do
      expect(delivery.entregar(subscription, 'demanda_criada', {})).to be true
    end

    it 'retorna false quando o endpoint responde com erro' do
      delivery_com_falha = described_class.new(transport: ->(_uri, _body) { resposta_falha })

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
      delivery_com_erro = described_class.new(transport: ->(_uri, _body) { raise SocketError, 'falha de rede' })

      expect(delivery_com_erro.entregar(subscription, 'demanda_criada', {})).to be false
    end
  end

  describe '.entregar' do
    it 'delega para uma instância nova' do
      expect(described_class.entregar(nil, 'demanda_criada', {})).to be false
    end
  end
end
