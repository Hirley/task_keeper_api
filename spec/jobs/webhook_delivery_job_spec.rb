# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookDeliveryJob, type: :job do
  describe '#perform' do
    it 'busca a assinatura pelo id e delega a entrega pra WebhookDelivery' do
      subscription = create(:webhook_subscription)

      expect(WebhookDelivery).to receive(:entregar).with(subscription, 'demanda_criada', { id: 1 })

      described_class.new.perform(subscription.id, 'demanda_criada', { id: 1 })
    end

    it 'não levanta erro se a assinatura já não existe mais (ex.: foi excluída antes do job rodar)' do
      expect(WebhookDelivery).to receive(:entregar).with(nil, 'demanda_criada', { id: 1 })

      expect { described_class.new.perform(0, 'demanda_criada', { id: 1 }) }.not_to raise_error
    end
  end
end
