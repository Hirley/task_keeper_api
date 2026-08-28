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

  # Ver Api::V1::UsersController::CAMPOS_PUBLICOS. A serialização daqui era
  # uma blocklist (`except: %i[encrypted_password reset_password_token]`),
  # então toda coluna nova da tabela users nascia publicada na API e só
  # deixava de ser se alguém lembrasse de excluí-la — foi assim que o
  # telegram_chat_id, que só admin pode gravar, passou a ser devolvido a
  # qualquer líder. Os dois primeiros exemplos fecham a lista de propósito:
  # uma coluna nova que apareça na resposta sem passar por CAMPOS_PUBLICOS
  # quebra o spec em vez de vazar em silêncio.
  describe 'serialização do usuário' do
    let(:campos_esperados) { %w[id name email role must_change_password created_at updated_at] }
    let!(:com_telegram) { create(:user, :executor, telegram_chat_id: '123456789') }

    it 'devolve exatamente os campos públicos para um líder' do
      sign_in lider

      get '/api/v1/users'

      serializado = response.parsed_body.find { |usuario| usuario['id'] == com_telegram.id }
      expect(serializado.keys).to contain_exactly(*campos_esperados)
    end

    it 'acrescenta o telegram_chat_id para um admin, que é quem pode gravá-lo' do
      sign_in admin

      get "/api/v1/users/#{com_telegram.id}"

      expect(response.parsed_body.keys).to contain_exactly(*campos_esperados, 'telegram_chat_id')
      expect(response.parsed_body['telegram_chat_id']).to eq('123456789')
    end

    it 'não devolve material do Devise nem para o admin' do
      sign_in admin

      get "/api/v1/users/#{com_telegram.id}"

      %w[encrypted_password reset_password_token reset_password_sent_at remember_created_at].each do |campo|
        expect(response.parsed_body).not_to have_key(campo)
      end
    end

    it 'aplica a mesma lista na resposta do cadastro' do
      sign_in lider

      post '/api/v1/users', params: novo_usuario_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to contain_exactly(*campos_esperados)
    end
  end
end
