# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

module Relatorios
  # Gera o PDF do relatório semanal (ver Relatorios::Semanal pros dados) —
  # usado tanto pro download direto (RelatoriosController#semanal_pdf)
  # quanto pro envio via Telegram (TelegramNotifier#enviar_documento).
  class SemanalPdf
    def initialize(relatorio)
      @relatorio = relatorio
    end

    def render
      Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
        cabecalho(pdf)
        resumo(pdf)
        tabela_demandas(pdf, 'Demandas criadas na semana', @relatorio.criadas)
        tabela_demandas(pdf, 'Demandas concluídas na semana', @relatorio.concluidas)
        carga_por_responsavel(pdf)
      end.render
    end

    private

    def cabecalho(pdf)
      pdf.text 'Task Keeper API — Relatório semanal', size: 18, style: :bold
      periodo = "#{@relatorio.periodo_inicio.strftime('%d/%m/%Y')} a #{@relatorio.periodo_fim.strftime('%d/%m/%Y')}"
      pdf.text "Período: #{periodo}", size: 11, color: '666666'
      pdf.move_down 16
    end

    def resumo(pdf)
      pdf.text 'Situação atual', size: 13, style: :bold
      pdf.move_down 4

      linhas = @relatorio.status_counts.map { |status, count| ["#{status.humanize}: #{count}"] }
      linhas << ["Atrasadas (hoje): #{@relatorio.atrasadas}"]
      linhas << ["Criadas na semana: #{@relatorio.criadas.size}"]
      linhas << ["Concluídas na semana: #{@relatorio.concluidas.size}"]

      linhas.each { |linha| pdf.text "• #{linha.first}", size: 10 }
      pdf.move_down 16
    end

    def tabela_demandas(pdf, titulo, demandas)
      pdf.text titulo, size: 13, style: :bold
      pdf.move_down 4

      if demandas.empty?
        pdf.text 'Nenhuma.', size: 10, color: '666666'
      else
        linhas = [%w[Título Responsável Status Data]]
        demandas.each do |demanda|
          linhas << [demanda.title, demanda.user&.name.to_s, demanda.status.humanize, demanda.data.strftime('%d/%m/%Y')]
        end

        pdf.table(linhas, header: true, width: pdf.bounds.width) do |t|
          t.row(0).font_style = :bold
          t.row(0).background_color = 'EEEEEE'
          t.cells.size = 9
          t.cells.padding = 6
        end
      end

      pdf.move_down 16
    end

    def carga_por_responsavel(pdf)
      pdf.text 'Carga atual por responsável (demandas não concluídas)', size: 13, style: :bold
      pdf.move_down 4

      if @relatorio.carga_por_responsavel.empty?
        pdf.text 'Nenhuma.', size: 10, color: '666666'
      else
        linhas = [['Responsável', 'Demandas em aberto']]
        @relatorio.carga_por_responsavel.each { |nome, count| linhas << [nome, count.to_s] }

        pdf.table(linhas, header: true, width: pdf.bounds.width) do |t|
          t.row(0).font_style = :bold
          t.row(0).background_color = 'EEEEEE'
          t.cells.size = 9
          t.cells.padding = 6
        end
      end
    end
  end
end
