# frozen_string_literal: true

module Relatorios
  # Geração sob demanda do relatório semanal em PDF: monta os dados
  # (Relatorios::Semanal), anuncia o evento "relatorio_gerado" pros
  # webhooks cadastrados e devolve os bytes do PDF
  # (Relatorios::SemanalPdf).
  #
  # É uma classe separada do SemanalPdf, que é só o renderizador, porque
  # anunciar o evento não é assunto de quem desenha o documento — e
  # porque os dois caminhos que geram o PDF de verdade (o download em
  # RelatoriosController#semanal_pdf e o envio por Telegram em
  # RelatorioSemanalTelegramJob) precisam fazer exatamente a mesma coisa.
  # Repetir a montagem do payload nos dois era garantia de eles
  # divergirem no primeiro campo novo.
  #
  # RelatoriosController#show não passa por aqui de propósito: a
  # pré-visualização é aberta toda vez que alguém entra em /relatorios, e
  # disparar um evento externo a cada visita seria ruído. Só o download e
  # o envio — ações deliberadas — contam como "relatório gerado".
  class GerarPdfSemanal
    def self.call
      new.call
    end

    def call
      relatorio = Semanal.new.gerar
      WebhookDispatcher.dispatch('relatorio_gerado', webhook_payload(relatorio))
      SemanalPdf.new(relatorio).render
    end

    private

    def webhook_payload(relatorio)
      {
        periodo_inicio: relatorio.periodo_inicio.iso8601,
        periodo_fim: relatorio.periodo_fim.iso8601,
        total_criadas: relatorio.criadas.size,
        total_concluidas: relatorio.concluidas.size,
        total_atrasadas: relatorio.atrasadas,
        status_counts: relatorio.status_counts
      }
    end
  end
end
