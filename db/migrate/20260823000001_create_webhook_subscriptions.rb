# frozen_string_literal: true

class CreateWebhookSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_subscriptions do |t|
      t.string :url, null: false
      # Array nativo do Postgres (ver app/models/webhook_subscription.rb,
      # WebhookSubscription::EVENTS) — evita uma tabela de junção só pra
      # guardar quais eventos cada webhook escuta.
      t.string :events, array: true, null: false, default: []
      t.boolean :active, null: false, default: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
