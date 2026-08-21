# frozen_string_literal: true

# Relatório semanal de demandas — só o líder tem acesso (ver
# app/models/ability.rb: líder tem `can :manage, :all`, que já cobre o
# símbolo :relatorio usado em #authorize_relatorio!; executor não tem
# nenhuma permissão concedida sobre isso, então fica bloqueado por
# padrão). Geração é sob demanda (o líder decide quando gerar/baixar/
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

  def gerar_pdf
    Relatorios::SemanalPdf.new(Relatorios::Semanal.new.gerar).render
  end

  def nome_arquivo
    "relatorio-semanal-task-keeper-#{Date.current.iso8601}.pdf"
  end
end
