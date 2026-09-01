# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelatorioSemanalTelegramJob, type: :job do
  let(:usuario) { create(:user, :lider, telegram_chat_id: '111222333') }
  let(:notifier) { instance_double(TelegramNotifier) }

  before do
    allow(TelegramNotifier).to receive(:new).and_return(notifier)
    allow(notifier).to receive(:enviar_documento).and_return(true)
  end

  describe '#perform' do
    it 'gera o PDF e manda como documento pro Chat ID de quem pediu' do
      described_class.new.perform(usuario.id)

      expect(notifier).to have_received(:enviar_documento).with(
        usuario,
        filename: Relatorios::SemanalPdf.nome_arquivo,
        conteudo: start_with('%PDF'),
        legenda: described_class::LEGENDA
      )
    end

    it 'dispara o webhook "relatorio_gerado" (a geração acontece aqui agora, não mais na tela)' do
      allow(WebhookDispatcher).to receive(:dispatch)

      described_class.new.perform(usuario.id)

      expect(WebhookDispatcher).to have_received(:dispatch)
        .with('relatorio_gerado', hash_including(:periodo_inicio, :periodo_fim))
    end

    it 'não tenta enviar nada se o usuário já não existe mais' do
      described_class.new.perform(0)

      expect(notifier).not_to have_received(:enviar_documento)
    end

    # Quem pediu já viu "chega em instantes" — a tela não existe mais pra
    # avisar. O log é a única trilha que sobra, então ele precisa existir.
    it 'registra no log quando o envio falha' do
      allow(notifier).to receive(:enviar_documento).and_return(false)
      allow(Rails.logger).to receive(:warn)

      described_class.new.perform(usuario.id)

      expect(Rails.logger).to have_received(:warn).with(/não consegui enviar o relatório semanal/)
    end
  end
end
