# frozen_string_literal: true

# Gera o PDF do relatório semanal e envia pro Telegram de quem pediu,
# fora da requisição.
#
# Antes isso rodava inteiro dentro do POST /relatorios/enviar_telegram: a
# tela ficava presa montando o documento E esperando o upload pra API do
# Telegram terminar. Com RAILS_MAX_THREADS no default de 5, um Telegram
# lento prendia um worker do Puma por requisição — poucos pedidos
# simultâneos bastavam pra degradar a aplicação inteira, inclusive as
# telas que não têm nada a ver com relatório.
#
# Recebe o id, e não o registro: o job pode rodar depois de o usuário ser
# excluído, e nesse caso a deserialização de um GlobalID levantaria
# erro em vez de simplesmente não ter o que fazer.
class RelatorioSemanalTelegramJob < ApplicationJob
  queue_as :default

  LEGENDA = 'Relatório semanal — Task Keeper API'

  def perform(user_id)
    usuario = User.find_by(id: user_id)
    return if usuario.nil?

    enviado = TelegramNotifier.new.enviar_documento(
      usuario,
      filename: Relatorios::SemanalPdf.nome_arquivo,
      conteudo: Relatorios::GerarPdfSemanal.call,
      legenda: LEGENDA
    )
    return if enviado

    # Os dois motivos previsíveis de não enviar (servidor sem
    # TELEGRAM_BOT_TOKEN, usuário sem Chat ID) já foram barrados na tela,
    # antes de enfileirar — ver RelatoriosController#enviar_telegram.
    # Chegar aqui com false é falha no envio em si, e quem pediu já
    # recebeu "chega em instantes": não há mais tela pra avisar. Sobra o
    # log, que é o motivo de ele existir.
    Rails.logger.warn(
      "[RelatorioSemanalTelegramJob] não consegui enviar o relatório semanal pro usuário ##{usuario.id}"
    )
  end
end
