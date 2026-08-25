# frozen_string_literal: true

require 'rails_helper'

# Primeiro acesso: novo usuário loga com a senha provisória cadastrada
# pelo líder/admin e, logo em seguida, é obrigado a cadastrar a própria
# senha antes de usar qualquer outra tela (ver
# ApplicationController#exigir_troca_de_senha! e DefinirSenhaController).
RSpec.describe 'Definir senha no primeiro acesso', type: :request do
  let(:novo_usuario) { create(:user, :primeiro_acesso, email: 'novato@task-keeper.local') }

  describe 'acesso a qualquer tela com troca de senha pendente' do
    it 'redireciona para /definir-senha' do
      sign_in novo_usuario

      get demandas_path

      expect(response).to redirect_to(edit_definir_senha_path)
    end

    it 'redireciona mesmo a página inicial' do
      sign_in novo_usuario

      get root_path

      expect(response).to redirect_to(edit_definir_senha_path)
    end

    it 'não redireciona um usuário que já definiu a própria senha' do
      usuario = create(:user, :executor)
      sign_in usuario

      get demandas_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /definir-senha' do
    it 'exibe o formulário pro usuário com troca pendente' do
      sign_in novo_usuario

      get edit_definir_senha_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Defina sua senha')
    end
  end

  describe 'PATCH /definir-senha' do
    it 'define a nova senha e libera o acesso às demais telas' do
      sign_in novo_usuario

      patch definir_senha_path,
            params: { user: { password: 'minhaSenhaPropria1', password_confirmation: 'minhaSenhaPropria1' } }

      expect(response).to redirect_to(root_path)
      expect(novo_usuario.reload.must_change_password?).to be false
      expect(novo_usuario.valid_password?('minhaSenhaPropria1')).to be true
    end

    it 'permite continuar navegando normalmente depois de definir a senha' do
      sign_in novo_usuario
      patch definir_senha_path,
            params: { user: { password: 'minhaSenhaPropria1', password_confirmation: 'minhaSenhaPropria1' } }

      get demandas_path

      expect(response).to have_http_status(:ok)
    end

    it 'não libera o acesso quando a confirmação não bate com a senha' do
      sign_in novo_usuario

      patch definir_senha_path,
            params: { user: { password: 'minhaSenhaPropria1', password_confirmation: 'outraSenha' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(novo_usuario.reload.must_change_password?).to be true
    end

    it 'não libera o acesso quando a senha é muito curta' do
      sign_in novo_usuario

      patch definir_senha_path, params: { user: { password: '123', password_confirmation: '123' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(novo_usuario.reload.must_change_password?).to be true
    end
  end

  describe 'logout com troca de senha pendente' do
    it 'permite que o usuário faça logout mesmo sem ter trocado a senha' do
      sign_in novo_usuario

      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
    end
  end
end
