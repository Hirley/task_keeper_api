class AddTelegramNotificationFields < ActiveRecord::Migration[8.1]
  def change
    # Preenchido pelo líder em /users (ver app/views/users/_form.html.haml)
    # com o chat_id do Telegram do usuário, para que ele possa receber
    # lembretes de demandas atrasadas (ver app/services/telegram_notifier.rb).
    add_column :users, :telegram_chat_id, :string

    # Marca quando o executor já foi avisado sobre o atraso de uma demanda
    # específica, para o lembrete ser enviado só uma vez por atraso (ver
    # lib/tasks/telegram_notifications.rake). Fica nulo de novo se a
    # demanda deixar de estar atrasada (ver Demanda#before_save).
    add_column :demandas, :atraso_notificado_em, :datetime
  end
end
