# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  let(:novo_usuario_params) do
    {
      user: {
        name: 'Novo Usuário',
        email: 'novo.usuario@task-keeper.local',
        password: 'senhaSegura123',
        password_confirmation: 'senhaSegura123',
        role: 'executor'
      }
    }
  end

  describe 'GET /api/v1/users' do
    it 'bloqueia um executor com 403' do
      sign_in executor
      get '/api/v1/users'
      expect(response).to have_http_status(:forbidden)
    end

    it 'permite que um líder liste os usuários' do
      sign_in lider
      get '/api/v1/users'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/users' do
    it 'bloqueia um executor com 403 e não cria o usuário' do
      sign_in executor
      expect do
        post '/api/v1/users', params: novo_usuario_params, as: :json
      end.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    # A API não pode ser a porta dos fundos da regra que a tela web
    # aplica — ver User#validar_atribuicao_de_papel.
    it 'não deixa um líder cadastrar um admin' do
      sign_in lider

      expect do
        post '/api/v1/users', params: { user: novo_usuario_params[:user].merge(role: 'admin') }, as: :json
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'deixa um admin cadastrar outro admin' do
      sign_in admin

      post '/api/v1/users', params: { user: novo_usuario_params[:user].merge(role: 'admin') }, as: :json

      expect(response).to have_http_status(:created)
      expect(User.find_by(email: 'novo.usuario@task-keeper.local')).to be_admin
    end

    it 'permite que um líder cadastre um novo usuário' do
      sign_in lider
      expect do
        post '/api/v1/users', params: novo_usuario_params, as: :json
      end.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'salva o telegram_chat_id quando quem cadastra é admin' do
      sign_in admin
      params = novo_usuario_params.deep_merge(user: { telegram_chat_id: '999888777' })

      post '/api/v1/users', params: params, as: :json

      expect(User.last.telegram_chat_id).to eq('999888777')
    end

    it 'ignora o telegram_chat_id quando quem cadastra é líder (não admin)' do
      sign_in lider
      params = novo_usuario_params.deep_merge(user: { telegram_chat_id: '999888777' })

      post '/api/v1/users', params: params, as: :json

      expect(User.last.telegram_chat_id).to be_nil
    end
  end

  describe 'DELETE /api/v1/users/:id' do
    let!(:outro_usuario) { create(:user, :executor) }

    it 'bloqueia um executor com 403 e não exclui o usuário' do
      sign_in executor
      expect do
        delete "/api/v1/users/#{outro_usuario.id}", as: :json
      end.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'permite que um líder exclua outro usuário' do
      sign_in lider
      expect do
        delete "/api/v1/users/#{outro_usuario.id}", as: :json
      end.to change(User, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'impede que o líder exclua o próprio usuário' do
      sign_in lider
      expect do
        delete "/api/v1/users/#{lider.id}", as: :json
      end.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/não pode excluir o seu próprio usuário/i)
    end

    it 'impede excluir um usuário que já tem demandas cadastradas' do
      create(:demanda, user: outro_usuario)
      sign_in lider

      expect do
        delete "/api/v1/users/#{outro_usuario.id}", as: :json
      end.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/demandas cadastradas/i)
    end
  end
end
