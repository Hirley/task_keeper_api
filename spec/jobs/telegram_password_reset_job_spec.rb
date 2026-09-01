# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TelegramPasswordResetJob, type: :job do
  describe '#perform' do
    it 'delega o envio pra Users::SendPasswordResetViaTelegram' do
      usuario = create(:user, telegram_chat_id: '555111222')
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      described_class.new.perform(usuario.id)

      expect(Users::SendPasswordResetViaTelegram).to have_received(:call).with(user: usuario)
    end

    # O job recebe um id justamente porque o registro pode mudar (ou
    # sumir) entre o POST e a execução — ver o comentário na classe.
    it 'não faz nada e não levanta erro se o usuário já não existe mais' do
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      expect { described_class.new.perform(0) }.not_to raise_error
      expect(Users::SendPasswordResetViaTelegram).not_to have_received(:call)
    end

    it 'não gera token nenhum se o Chat ID foi removido depois do pedido' do
      usuario = create(:user, telegram_chat_id: nil)
      allow(Users::SendPasswordResetViaTelegram).to receive(:call)

      described_class.new.perform(usuario.id)

      expect(Users::SendPasswordResetViaTelegram).not_to have_received(:call)
      expect(usuario.reload.reset_password_token).to be_nil
    end
  end
end
