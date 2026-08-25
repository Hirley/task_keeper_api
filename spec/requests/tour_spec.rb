# frozen_string_literal: true

require 'rails_helper'

# Guia interativo (tour) do dashboard — ver app/javascript/application.js
# (TkGuideTour) e app/views/dashboard/index.html.haml (#tk-tour-autostart).
# Essa rota só marca no servidor que o usuário já viu (ou pulou) o tour,
# pra ele não disparar sozinho de novo no próximo login.
RSpec.describe 'Tour guiado', type: :request do
  describe 'PATCH /tour/concluir' do
    it 'exige autenticação' do
      patch concluir_tour_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'marca tour_completed_at do usuário logado' do
      usuario = create(:user, :executor)
      sign_in usuario

      expect { patch concluir_tour_path }.to change { usuario.reload.tour_completed_at }.from(nil)

      expect(response).to have_http_status(:no_content)
    end

    it 'atualiza tour_completed_at mesmo quando já estava marcado (rever o tour não desfaz isso)' do
      usuario = create(:user, :executor, tour_completed_at: 1.day.ago)
      sign_in usuario

      expect { patch concluir_tour_path }.to change { usuario.reload.tour_completed_at }

      expect(response).to have_http_status(:no_content)
    end
  end
end
