# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Esqueci minha senha', type: :request do
  describe 'GET /users/sign_in' do
    it 'tem links para redefinir a senha por e-mail e por Telegram' do
      get new_user_session_path

      expect(response.body).to include(new_user_password_path)
      expect(response.body).to include(new_telegram_password_reset_path)
    end
  end

  describe 'POST /users/password (redefinição por e-mail)' do
    it 'envia um e-mail com um link de redefinição válido' do
      usuario = create(:user, email: 'esqueceu@task-keeper.local')

      expect do
        post user_password_path, params: { user: { email: usuario.email } }
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to eq([usuario.email])
      expect(email.body.encoded).to include(edit_user_password_path)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
