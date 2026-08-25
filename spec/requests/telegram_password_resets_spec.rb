# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Redefinição de senha por Telegram', type: :request do
  describe 'GET /senha/telegram' do
    it 'exibe o formulário sem exigir login' do
      get new_telegram_password_reset_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Redefinir por Telegram')
    end
  end

  describe 'POST /senha/telegram' do
    it 'aciona o envio por Telegram quando o e-mail existe e tem Chat ID cadastrado' do
      usuario = create(:user, email: 'comtelegram@task-keeper.local', telegram_chat_id: '555111222')
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      post telegram_password_resets_path, params: { email: usuario.email }

      expect(Users::SendPasswordResetViaTelegram).to have_received(:call).with(user: usuario)
      expect(response).to redirect_to(new_telegram_password_reset_path)
    end

    it 'não aciona nada quando o e-mail existe mas não tem Chat ID do Telegram cadastrado' do
      usuario = create(:user, email: 'semtelegram@task-keeper.local', telegram_chat_id: nil)
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      post telegram_password_resets_path, params: { email: usuario.email }

      expect(Users::SendPasswordResetViaTelegram).not_to have_received(:call)
    end

    it 'não aciona nada e não quebra quando o e-mail não existe' do
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      post telegram_password_resets_path, params: { email: 'ninguem@task-keeper.local' }

      expect(Users::SendPasswordResetViaTelegram).not_to have_received(:call)
      expect(response).to redirect_to(new_telegram_password_reset_path)
    end

    it 'mostra sempre a mesma mensagem genérica, exista ou não o e-mail (evita vazar quem está cadastrado)' do
      create(:user, email: 'comtelegram@task-keeper.local', telegram_chat_id: '555111222')
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      post telegram_password_resets_path, params: { email: 'comtelegram@task-keeper.local' }
      follow_redirect!
      mensagem_existente = response.body

      post telegram_password_resets_path, params: { email: 'ninguem@task-keeper.local' }
      follow_redirect!
      mensagem_inexistente = response.body

      texto = 'você vai receber uma mensagem com instruções para redefinir sua senha'
      expect(mensagem_existente).to include(texto)
      expect(mensagem_inexistente).to include(texto)
    end
  end
end
