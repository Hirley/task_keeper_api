# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookSubscription, type: :model do
  subject(:webhook_subscription) { build(:webhook_subscription) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:url) }
  it { is_expected.to validate_presence_of(:events) }

  it 'é válido com atributos válidos' do
    expect(webhook_subscription).to be_valid
  end

  describe 'validação de eventos' do
    it 'aceita qualquer combinação dos eventos conhecidos' do
      webhook_subscription.events = %w[demanda_criada relatorio_gerado]

      expect(webhook_subscription).to be_valid
    end

    it 'rejeita um evento desconhecido' do
      webhook_subscription.events = %w[demanda_criada evento_inventado]

      expect(webhook_subscription).not_to be_valid
      expect(webhook_subscription.errors[:events].join).to include('evento_inventado')
    end
  end

  describe 'validação de URL (proteção contra SSRF)' do
    it 'rejeita algo que não é uma URL http(s)' do
      webhook_subscription.url = 'não é uma url'

      expect(webhook_subscription).not_to be_valid
      expect(webhook_subscription.errors[:url]).to be_present
    end

    it 'rejeita um endereço loopback (127.0.0.1)' do
      webhook_subscription.url = 'http://127.0.0.1/hook'

      expect(webhook_subscription).not_to be_valid
      expect(webhook_subscription.errors[:url].join).to include('privado')
    end

    it 'rejeita um endereço de rede privada (192.168.x.x)' do
      webhook_subscription.url = 'http://192.168.1.10/hook'

      expect(webhook_subscription).not_to be_valid
    end

    it 'rejeita link-local (169.254.x.x — ex.: metadata de nuvem)' do
      webhook_subscription.url = 'http://169.254.169.254/latest/meta-data'

      expect(webhook_subscription).not_to be_valid
    end

    it 'aceita um endereço IP público' do
      webhook_subscription.url = 'http://8.8.8.8/hook'

      expect(webhook_subscription).to be_valid
    end

    it 'rejeita o loopback IPv6 (::1) sem levantar erro ao comparar família de endereço diferente' do
      webhook_subscription.url = 'http://[::1]/hook'

      expect { webhook_subscription.valid? }.not_to raise_error
      expect(webhook_subscription).not_to be_valid
    end
  end

  describe '.for_event' do
    it 'encontra só as assinaturas que escutam o evento pedido' do
      escuta = create(:webhook_subscription, events: %w[demanda_criada])
      nao_escuta = create(:webhook_subscription, events: %w[relatorio_gerado])

      resultado = described_class.for_event('demanda_criada')

      expect(resultado).to include(escuta)
      expect(resultado).not_to include(nao_escuta)
    end
  end

  describe '.active' do
    it 'encontra só as assinaturas ativas' do
      ativa = create(:webhook_subscription)
      inativa = create(:webhook_subscription, :inativo)

      expect(described_class.active).to include(ativa)
      expect(described_class.active).not_to include(inativa)
    end
  end
end
