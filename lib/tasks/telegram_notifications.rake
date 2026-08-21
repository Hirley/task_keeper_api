# frozen_string_literal: true

# Pensado para rodar periodicamente (ex.: uma vez por dia) via um
# scheduler externo — no Railway, um serviço "Cron Job" separado rodando
# `bin/rails demandas:notificar_atrasos`. Não é chamado automaticamente
# pela aplicação, porque "ficar atrasada" é um estado que só muda com a
# passagem do tempo, não com uma ação do usuário — precisa de alguém
# perguntando periodicamente "o que está atrasado agora?".
namespace :demandas do
  desc 'Envia um lembrete no Telegram para o responsável de cada demanda atrasada (uma vez por atraso)'
  task notificar_atrasos: :environment do
    if ENV['TELEGRAM_BOT_TOKEN'].blank?
      puts 'TELEGRAM_BOT_TOKEN não configurado — nada a fazer.'
      next
    end

    demandas_atrasadas = Demanda
                         .where.not(status: :concluida)
                         .where(data: ...Date.current)
                         .where(atraso_notificado_em: nil)
                         .includes(:user)

    if demandas_atrasadas.none?
      puts 'Nenhuma demanda atrasada pendente de notificação.'
      next
    end

    demandas_atrasadas.find_each do |demanda|
      if demanda.user&.telegram_chat_id.blank?
        puts "Pulei ##{demanda.id} (#{demanda.title}): responsável sem telegram_chat_id cadastrado."
        next
      end

      if TelegramNotifier.notify_atraso(demanda)
        demanda.update_column(:atraso_notificado_em, Time.current)
        puts "Notifiquei ##{demanda.id} (#{demanda.title}) -> #{demanda.user.name}"
      else
        puts "Falha ao notificar ##{demanda.id} (#{demanda.title})"
      end
    end
  end
end
