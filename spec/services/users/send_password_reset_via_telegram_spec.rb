# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::SendPasswordResetViaTelegram do
  let(:usuario) { create(:user, name: 'Ana Paula Souza', telegram_chat_id: '555111222') }
  let(:chamadas) { [] }
  let(:telegram_notifier) { instance_double(TelegramNotifier) }

  before do
    allow(telegram_notifier).to receive(:enviar_redefinicao_senha) do |usuario_recebido, url|
      chamadas << { usuario: usuario_recebido, url: url }
      true
    end
  end

  describe '.call' do
    it 'pede pro TelegramNotifier enviar um link de redefinição pro usuário' do
      described_class.call(user: usuario, telegram_notifier: telegram_notifier)

      expect(chamadas.size).to eq(1)
      expect(chamadas.first[:usuario]).to eq(usuario)
    end

    it 'monta o link apontando pra tela de redefinição de senha, com o token' do
      described_class.call(user: usuario, telegram_notifier: telegram_notifier)

      url = chamadas.first[:url]
      expect(url).to include('/users/password/edit')
      expect(url).to include('reset_password_token=')
    end

    it 'gera um token que o Devise reconhece como válido pra redefinir a senha desse usuário' do
      described_class.call(user: usuario, telegram_notifier: telegram_notifier)

      token = URI.decode_www_form(URI(chamadas.first[:url]).query).to_h['reset_password_token']
      usuario_redefinido = User.reset_password_by_token(
        reset_password_token: token, password: 'novaSenha123', password_confirmation: 'novaSenha123'
      )

      expect(usuario_redefinido).to eq(usuario)
      expect(usuario.reload.valid_password?('novaSenha123')).to be true
    end

    it 'devolve o retorno do TelegramNotifier' do
      resultado = described_class.call(user: usuario, telegram_notifier: telegram_notifier)

      expect(resultado).to be true
    end
  end
end
