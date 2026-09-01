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

  ALERTA_TELEGRAM_INDISPONIVEL = 'Não foi possível enviar pelo Telegram. Confira se o servidor tem ' \
                                 'TELEGRAM_BOT_TOKEN configurado e se você tem um Chat ID do Telegram ' \
                                 'cadastrado (em Acessos → Editar permissões).'

  AVISO_ENVIO_ENFILEIRADO = 'Relatório em preparação. Ele chega no seu Telegram em instantes.'

  def show
    @relatorio = Relatorios::Semanal.new.gerar
  end

  # GET /relatorios/semanal.pdf — baixa o mesmo relatório em PDF.
  #
  # Este continua síncrono: o PDF É a resposta, não há como devolvê-lo
  # depois. Só o envio por Telegram saiu da requisição, porque lá o
  # documento não vai pro navegador de quem pediu.
  def semanal_pdf
    send_data Relatorios::GerarPdfSemanal.call,
              filename: Relatorios::SemanalPdf.nome_arquivo,
              type: 'application/pdf',
              disposition: 'inline'
  end

  # POST /relatorios/enviar_telegram — enfileira a geração do PDF e o
  # envio pro Telegram do próprio líder que pediu (não pra outros
  # usuários — ver README).
  #
  # Gerar o documento e fazer o upload rodavam aqui dentro: a tela ficava
  # presa no tempo de resposta da API do Telegram, e um serviço de
  # terceiro lento prendia um worker do Puma por requisição. Ver
  # RelatorioSemanalTelegramJob.
  #
  # A checagem de disponibilidade continua AQUI, e não no job, porque os
  # dois motivos previsíveis de não conseguir enviar (servidor sem
  # TELEGRAM_BOT_TOKEN, usuário sem Chat ID) são exatamente o que o alerta
  # abaixo explica — e nenhum dos dois precisa tocar a rede pra ser
  # verificado. A tela continua dando o mesmo aviso útil de antes, sem
  # esperar o Telegram responder.
  #
  # O que se perde: uma falha no envio em si (Telegram fora do ar,
  # timeout) não aparece mais na tela — quem pediu vê "em instantes" e
  # nada chega; fica só no log do job. Trazer isso de volta pra tela
  # exigiria persistir o resultado de cada envio e uma tela pra consultar
  # o status, o que é desproporcional pro caso raro. A alternativa era
  # continuar prendendo um worker do Puma no tempo do Telegram por causa
  # dele.
  def enviar_telegram
    return redirect_to relatorios_path, alert: ALERTA_TELEGRAM_INDISPONIVEL unless envio_por_telegram_disponivel?

    RelatorioSemanalTelegramJob.perform_later(current_user.id)
    redirect_to relatorios_path, notice: AVISO_ENVIO_ENFILEIRADO
  end

  private

  def authorize_relatorio!
    authorize! :read, :relatorio
  end

  def envio_por_telegram_disponivel?
    TelegramNotifier.new.pode_enviar_para?(current_user)
  end
end
