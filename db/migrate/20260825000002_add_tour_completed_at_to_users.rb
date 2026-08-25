# frozen_string_literal: true

class AddTourCompletedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # nil por padrão: o guia interativo (ver app/javascript/application.js
    # TkGuideTour) inicia sozinho na primeira vez que o usuário chega ao
    # dashboard depois do primeiro acesso e marca esse campo ao terminar
    # ou pular. Usuário pode rever o tour quando quiser pelo botão 🧭 na
    # navbar (ver app/views/layouts/application.html.haml), o que não
    # mexe nesse campo — ele só controla o disparo automático.
    add_column :users, :tour_completed_at, :datetime
  end
end
