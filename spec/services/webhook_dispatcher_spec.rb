# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookDispatcher do
  describe '#dispatch' do
    it 'enfileira a entrega só pras assinaturas ativas que escutam o evento' do
      escuta_e_ativa = create(:webhook_subscription, events: %w[demanda_criada])
      escuta_mas_pausada = create(:webhook_subscription, :inativo, events: %w[demanda_criada])
      nao_escuta = create(:webhook_subscription, events: %w[relatorio_gerado])
      allow(WebhookDeliveryJob).to receive(:perform_later)

      described_class.dispatch('demanda_criada', { id: 1 })

      expect(WebhookDeliveryJob).to have_received(:perform_later).once.with(escuta_e_ativa.id, 'demanda_criada', { id: 1 })
      # sanity check: as outras duas realmente existem e não bateram no matcher acima
      expect([escuta_mas_pausada, nao_escuta]).to all(be_persisted)
    end

    it 'não enfileira nada quando não há assinatura pro evento' do
      create(:webhook_subscription, events: %w[relatorio_gerado])
      allow(WebhookDeliveryJob).to receive(:perform_later)

      described_class.dispatch('demanda_criada', { id: 1 })

      expect(WebhookDeliveryJob).not_to have_received(:perform_later)
    end
  end

  describe '.dispatch' do
    it 'delega para uma instância nova (funciona sem precisar instanciar manualmente)' do
      subscription = create(:webhook_subscription, events: %w[demanda_criada])
      allow(WebhookDeliveryJob).to receive(:perform_later)

      described_class.dispatch('demanda_criada', { id: 1 })

      expect(WebhookDeliveryJob).to have_received(:perform_later).with(subscription.id, 'demanda_criada', { id: 1 })
    end
  end
end
