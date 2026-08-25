# frozen_string_literal: true

# Guia interativo (tour) do dashboard — ver app/javascript/application.js
# (TkGuideTour). Essa ação só marca que o usuário já viu (pra não disparar
# sozinho de novo no próximo login); rever o tour manualmente pelo botão 🧭
# da navbar não passa por aqui. Sem `authorize!`: só mexe no próprio
# current_user, igual DefinirSenhaController.
class TourController < ApplicationController
  def concluir
    current_user.update_column(:tour_completed_at, Time.current)
    head :no_content
  end
end
