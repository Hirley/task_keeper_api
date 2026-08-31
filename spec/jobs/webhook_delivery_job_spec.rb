# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookDeliveryJob, type: :job do
  describe '#perform' do
    it 'busca a assinatura pelo id e delega a entrega pra WebhookDelivery' do
      subscription = create(:webhook_subscription)
      allow(WebhookDelivery).to receive(:entregar)

      described_class.new.perform(subscription.id, 'demanda_criada', { id: 1 })

      expect(WebhookDelivery).to have_received(:entregar).with(subscription, 'demanda_criada', { id: 1 })
    end

    it 'não levanta erro se a assinatura já não existe mais (ex.: foi excluída antes do job rodar)' do
      allow(WebhookDelivery).to receive(:entregar)

      expect { described_class.new.perform(0, 'demanda_criada', { id: 1 }) }.not_to raise_error
      expect(WebhookDelivery).to have_received(:entregar).with(nil, 'demanda_criada', { id: 1 })
    end
  end

  # Ver o retry_on em WebhookDeliveryJob e o contrato de retorno de
  # WebhookDelivery#entregar. O que se verifica aqui é a decisão do job:
  # reagendar só quando vale a pena, sem gastar tentativa numa recusa que
  # não vai mudar de resposta.
  describe 'retentativa' do
    let(:subscription) { create(:webhook_subscription) }
    let(:fila) { ActiveJob::Base.queue_adapter.enqueued_jobs }

    it 'reagenda quando a entrega falha por algo temporário' do
      allow(WebhookDelivery).to receive(:entregar).and_raise(WebhookDelivery::FalhaTemporaria, 'endpoint fora do ar')

      expect { described_class.perform_now(subscription.id, 'demanda_criada', {}) }
        .to change(fila, :size).by(1)
    end

    it 'não reagenda quando a recusa é definitiva' do
      allow(WebhookDelivery).to receive(:entregar).and_return(false)

      expect { described_class.perform_now(subscription.id, 'demanda_criada', {}) }
        .not_to change(fila, :size)
    end

    it 'não reagenda quando a entrega dá certo' do
      allow(WebhookDelivery).to receive(:entregar).and_return(true)

      expect { described_class.perform_now(subscription.id, 'demanda_criada', {}) }
        .not_to change(fila, :size)
    end
  end
end
