# frozen_string_literal: true

# Relatório semanal de demandas — líder e admin têm acesso (ver
# app/models/ability.rb: os dois têm `can :manage, :all`, que já cobre o
# símbolo :relatorio usado em #authorize_relatorio!; executor não tem
# nenhuma permissão concedida sobre isso, então fica bloqueado por
# padrão). Geração é sob demanda (quem acessa decide quando gerar/baixar/
# enviar), não há envio automático agendado — ver README, seção
# "Relatório semanal".
class RelatoriosController < ApplicationController
  before_action :authorize_relatorio!

  def show
    @relatorio = Relatorios::Semanal.new.gerar
  end

  # GET /relatorios/semanal.pdf — baixa o mesmo relatório em PDF.
  def semanal_pdf
    pdf = gerar_pdf
    send_data pdf, filename: nome_arquivo, type: 'application/pdf', disposition: 'inline'
  end

  # POST /relatorios/enviar_telegram — envia o PDF pro Telegram do próprio
  # líder que pediu (não pra outros usuários — ver README).
  def enviar_telegram
    pdf = gerar_pdf
    enviado = TelegramNotifier.new.enviar_documento(
      current_user,
      filename: nome_arquivo,
      conteudo: pdf,
      legenda: 'Relatório semanal — Task Keeper API'
    )

    if enviado
      redirect_to relatorios_path, notice: 'Relatório enviado no seu Telegram.'
    else
      redirect_to relatorios_path,
                  alert: 'Não foi possível enviar pelo Telegram. Confira se o servidor tem TELEGRAM_BOT_TOKEN ' \
                         'configurado e se você tem um Chat ID do Telegram cadastrado (em Acessos → Editar permissões).'
    end
  end

  private

  def authorize_relatorio!
    authorize! :read, :relatorio
  end

  # Dispara o webhook "relatorio_gerado" aqui (não em #show) porque #show
  # é a tela de pré-visualização, visitada toda vez que o líder abre
  # /relatorios — disparar um evento externo a cada visita seria ruído.
  # #gerar_pdf só roda quando o líder efetivamente baixa ou envia o PDF
  # (ações deliberadas), ver #semanal_pdf e #enviar_telegram.
  def gerar_pdf
    relatorio = Relatorios::Semanal.new.gerar
    WebhookDispatcher.dispatch('relatorio_gerado', relatorio_webhook_payload(relatorio))
    Relatorios::SemanalPdf.new(relatorio).render
  end

  def relatorio_webhook_payload(relatorio)
    {
      periodo_inicio: relatorio.periodo_inicio.iso8601,
      periodo_fim: relatorio.periodo_fim.iso8601,
      total_criadas: relatorio.criadas.size,
      total_concluidas: relatorio.concluidas.size,
      total_atrasadas: relatorio.atrasadas,
      status_counts: relatorio.status_counts
    }
  end

  def nome_arquivo
    "relatorio-semanal-task-keeper-#{Date.current.iso8601}.pdf"
  end
end
