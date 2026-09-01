# frozen_string_literal: true

# Pensado para rodar periodicamente (ex.: uma vez por dia) via um
# scheduler externo — no Railway, um serviço "Cron Job" separado rodando
# `bin/rails demandas:notificar_atrasos`. Não é chamado automaticamente
# pela aplicação, porque "ficar atrasada" é um estado que só muda com a
# passagem do tempo, não com uma ação do usuário — precisa de alguém
# perguntando periodicamente "o que está atrasado agora?". Ver README,
# seção "Notificação de atraso via Telegram".
namespace :demandas do
  desc 'Envia um lembrete no Telegram para o responsável de cada demanda atrasada (uma vez por atraso)'
  task notificar_atrasos: :environment do
    # Reivindica a demanda ANTES de enviar, com um UPDATE condicional:
    # quem escreve a linha é quem envia. É isso que torna "uma vez por
    # atraso" — a promessa do README — verdade também fora do caminho
    # feliz de execução única.
    #
    # Antes a ordem era selecionar, enviar, e só então gravar. Duas
    # janelas de duplicação vinham daí: duas execuções simultâneas (cron
    # disparado duas vezes, retry do scheduler, réplica extra) selecionavam
    # a mesma demanda antes de qualquer gravação e notificavam as duas; e
    # uma morte de processo entre o envio e a gravação fazia a execução
    # seguinte notificar de novo.
    #
    # O UPDATE ... WHERE atraso_notificado_em IS NULL resolve as duas de
    # uma vez, porque a checagem e a escrita acontecem no mesmo comando: o
    # banco decide quem venceu, e só o vencedor recebe 1 linha afetada.
    reivindicar = lambda do |demanda|
      Demanda.where(id: demanda.id, atraso_notificado_em: nil)
             .update_all(atraso_notificado_em: Time.current) == 1
    end

    # Devolve a reivindicação quando o envio falha de forma declarada
    # (TelegramNotifier#notify_atraso devolveu false), para que a próxima
    # execução tente de novo — é o comportamento que já existia, e não há
    # motivo para perdê-lo junto com a correção da corrida.
    #
    # O que NÃO é devolvido: uma demanda cujo processo morra entre a
    # reivindicação e o envio. Aquela notificação é gasta sem sair, e essa
    # é a troca consciente de reivindicar antes de enviar. Perder um
    # lembrete numa queda é melhor que mandar o mesmo lembrete duas vezes
    # em toda execução concorrente.
    #
    # Sobra uma janela estreita: um transporte que devolva false depois de
    # a mensagem ter sido entregue (timeout na leitura da resposta, por
    # exemplo) faz a próxima execução notificar de novo. É estritamente
    # menor que a janela de antes, e o modo de falha é o mesmo que já
    # existia.
    devolver = lambda do |demanda|
      Demanda.where(id: demanda.id).update_all(atraso_notificado_em: nil)
    end

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

      unless reivindicar.call(demanda)
        puts "Pulei ##{demanda.id} (#{demanda.title}): outra execução reivindicou a notificação antes."
        next
      end

      if TelegramNotifier.notify_atraso(demanda)
        puts "Notifiquei ##{demanda.id} (#{demanda.title}) -> #{demanda.user.name}"
      else
        devolver.call(demanda)
        puts "Falha ao notificar ##{demanda.id} (#{demanda.title}) — devolvida para a próxima execução."
      end
    end
  end
end
