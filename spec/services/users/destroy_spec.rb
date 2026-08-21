# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Destroy do
  let(:lider) { create(:user, :lider) }

  describe '.call' do
    it 'exclui o usuário e retorna sucesso quando não há impeditivo' do
      outro_usuario = create(:user, :executor)

      result = described_class.call(user: outro_usuario, actor: lider)

      expect(result.success?).to be true
      expect(result.user).to eq(outro_usuario)
      expect(User.exists?(outro_usuario.id)).to be false
    end

    it 'não exclui e retorna falha quando o usuário tenta excluir a si mesmo' do
      result = described_class.call(user: lider, actor: lider)

      expect(result.success?).to be false
      expect(result.error_code).to eq(:self_deletion)
      expect(result.error_message).to match(/não pode excluir o seu próprio usuário/i)
      expect(User.exists?(lider.id)).to be true
    end

    it 'não exclui e retorna falha quando o usuário tem demandas cadastradas' do
      outro_usuario = create(:user, :executor, name: 'Bruno Lima')
      create(:demanda, user: outro_usuario)

      result = described_class.call(user: outro_usuario, actor: lider)

      expect(result.success?).to be false
      expect(result.error_code).to eq(:user_has_demandas)
      expect(result.error_message).to include('Bruno Lima')
      expect(result.error_message).to match(/demandas cadastradas/i)
      expect(User.exists?(outro_usuario.id)).to be true
    end

    it 'usa a mesma mensagem de erro independente de quem chama (evita divergência entre Web e API)' do
      outro_usuario = create(:user, :executor, name: 'Carla Nunes')
      create(:demanda, user: outro_usuario)

      resultado_um = described_class.call(user: outro_usuario, actor: lider)
      resultado_dois = described_class.call(user: outro_usuario, actor: lider)

      expect(resultado_um.error_message).to eq(resultado_dois.error_message)
    end
  end
end
