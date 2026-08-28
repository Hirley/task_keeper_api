# frozen_string_literal: true

require 'rails_helper'

# Ver app/controllers/concerns/auth_throttling.rb. Os limites vêm das
# constantes de lá de propósito: se alguém afrouxar a política, o teste
# acompanha em vez de quebrar por um número mágico desatualizado — o que
# o teste garante é que os DOIS eixos (IP e e-mail) existem e funcionam.
RSpec.describe 'Throttle das telas de autenticação', type: :request do
  let(:user) { create(:user, password: 'senhaSegura123') }

  def tentar_login(email:, senha: 'senha-errada', ip: '203.0.113.1')
    post '/users/sign_in',
         params: { user: { email: email, password: senha } },
         env: { 'REMOTE_ADDR' => ip }
  end

  describe 'POST /users/sign_in' do
    it 'bloqueia por IP quando as tentativas passam do limite' do
      # E-mail diferente a cada tentativa: isola o eixo de IP, senão o
      # limite por e-mail (mais baixo) estouraria antes.
      AuthThrottling::LIMITE_POR_IP.times do |i|
        tentar_login(email: "alvo#{i}@task-keeper.local")
        expect(response).not_to redirect_to(new_user_session_path)
      end

      tentar_login(email: 'ultimo@task-keeper.local')

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(AuthThrottling::MENSAGEM_LIMITE)
    end

    it 'bloqueia por e-mail mesmo com cada tentativa vindo de um IP diferente' do
      AuthThrottling::LIMITE_POR_EMAIL.times do |i|
        tentar_login(email: user.email, ip: "198.51.100.#{i + 1}")
        expect(flash[:alert]).not_to eq(AuthThrottling::MENSAGEM_LIMITE)
      end

      tentar_login(email: user.email, ip: '198.51.100.200')

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(AuthThrottling::MENSAGEM_LIMITE)
    end

    it 'conta o mesmo e-mail escrito com outra caixa/espaçamento no mesmo contador' do
      AuthThrottling::LIMITE_POR_EMAIL.times do |i|
        tentar_login(email: "  #{user.email.upcase}  ", ip: "198.51.100.#{i + 1}")
      end

      tentar_login(email: user.email, ip: '198.51.100.200')

      expect(flash[:alert]).to eq(AuthThrottling::MENSAGEM_LIMITE)
    end

    it 'não atrapalha um login normal' do
      tentar_login(email: user.email, senha: 'senhaSegura123')

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_blank
    end
  end

  describe 'POST /senha/telegram' do
    it 'bloqueia o disparo repetido de mensagens pro mesmo e-mail' do
      AuthThrottling::LIMITE_POR_EMAIL.times do |i|
        post '/senha/telegram', params: { email: user.email }, env: { 'REMOTE_ADDR' => "198.51.100.#{i + 1}" }
      end

      post '/senha/telegram', params: { email: user.email }, env: { 'REMOTE_ADDR' => '198.51.100.200' }

      expect(response).to redirect_to(new_telegram_password_reset_path)
      expect(flash[:alert]).to eq(AuthThrottling::MENSAGEM_LIMITE)
    end
  end

  describe 'POST /users/password (esqueci minha senha por e-mail)' do
    it 'bloqueia o disparo repetido de e-mails pro mesmo endereço' do
      AuthThrottling::LIMITE_POR_EMAIL.times do |i|
        post '/users/password',
             params: { user: { email: user.email } },
             env: { 'REMOTE_ADDR' => "198.51.100.#{i + 1}" }
      end

      post '/users/password',
           params: { user: { email: user.email } },
           env: { 'REMOTE_ADDR' => '198.51.100.200' }

      expect(response).to redirect_to(new_user_password_path)
      expect(flash[:alert]).to eq(AuthThrottling::MENSAGEM_LIMITE)
    end
  end
end
