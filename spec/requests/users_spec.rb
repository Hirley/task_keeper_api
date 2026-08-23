# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Usuários (tela web de Acessos)', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }
  let(:novo_usuario_params) do
    {
      user: {
        name: 'Novo Usuário',
        email: 'novo.acesso@task-keeper.local',
        password: 'senha123456',
        password_confirmation: 'senha123456',
        role: 'executor'
      }
    }
  end

  # A tela de listagem tem um <datalist> de autocomplete com TODOS os
  # nomes/e-mails cadastrados (sem respeitar filtro — é só sugestão de
  # busca). Para não confundir esse datalist com os resultados exibidos
  # na tabela, os testes de filtro devem inspecionar apenas o HTML
  # dentro do <tbody> da tabela de resultados (mesmo padrão usado em
  # spec/requests/demandas_spec.rb).
  def results_table(response)
    response.body[%r{<tbody>.*?</tbody>}m]
  end

  describe 'GET /users' do
    it 'bloqueia um executor' do
      sign_in executor
      get '/users'
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder veja a lista de acessos' do
      sign_in lider
      get '/users'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Acessos')
    end

    it 'não repete o título da página como um heading visível igual ao item do menu' do
      sign_in lider
      get '/users'

      expect(response.body).to include('<title>Acessos · Task Keeper API</title>')
      expect(response.body).to include('visually-hidden')
    end

    it 'filtra por nome/e-mail via o formulário de busca' do
      create(:user, name: 'Ana Souza', email: 'ana@task-keeper.local')
      create(:user, name: 'Bruno Lima', email: 'bruno@task-keeper.local')
      sign_in lider

      get '/users', params: { q: 'Ana' }

      expect(results_table(response)).to include('Ana Souza')
      expect(results_table(response)).not_to include('Bruno Lima')
    end

    it 'filtra por permissão' do
      create(:user, :lider, name: 'Outra Liderança')
      create(:user, :executor, name: 'Outro Executor')
      sign_in lider

      get '/users', params: { role: 'lider' }

      expect(results_table(response)).to include('Outra Liderança')
      expect(results_table(response)).not_to include('Outro Executor')
    end

    it 'filtra por mais de uma permissão ao mesmo tempo (select multiple)' do
      create(:user, :lider, name: 'Fulano Líder')
      create(:user, :executor, name: 'Fulano Executor')
      create(:user, :executor, name: 'Nunca aparece', email: 'outro-usuario@task-keeper.local')
      sign_in lider

      get '/users', params: { role: %w[lider executor], q: 'Fulano' }

      expect(results_table(response)).to include('Fulano Líder')
      expect(results_table(response)).to include('Fulano Executor')
      expect(results_table(response)).not_to include('Nunca aparece')
    end

    it 'filtra por mais de um termo de busca, separados por vírgula' do
      create(:user, name: 'Ana Souza', email: 'ana@task-keeper.local')
      create(:user, name: 'Bruno Lima', email: 'bruno@task-keeper.local')
      create(:user, name: 'Carlos Dias', email: 'carlos@task-keeper.local')
      sign_in lider

      get '/users', params: { q: 'Ana, Bruno' }

      table = results_table(response)
      expect(table).to include('Ana Souza')
      expect(table).to include('Bruno Lima')
      expect(table).not_to include('Carlos Dias')
    end

    it 'por padrão ordena por nome, A-Z' do
      create(:user, name: 'Zebra')
      create(:user, name: 'Abacaxi')
      sign_in lider

      get '/users'

      table = results_table(response)
      expect(table.index('Abacaxi')).to be < table.index('Zebra')
    end

    it 'ordena por nome, Z-A, quando a coluna é clicada de novo' do
      create(:user, name: 'Zebra')
      create(:user, name: 'Abacaxi')
      sign_in lider

      get '/users', params: { sort: 'name', direction: 'desc' }

      table = results_table(response)
      expect(table.index('Zebra')).to be < table.index('Abacaxi')
    end

    it 'ordena por e-mail' do
      create(:user, name: 'Usuário 1', email: 'zzz@task-keeper.local')
      create(:user, name: 'Usuário 2', email: 'aaa@task-keeper.local')
      sign_in lider

      get '/users', params: { sort: 'email', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Usuário 2')).to be < table.index('Usuário 1')
    end

    it 'ordena por permissão' do
      create(:user, :lider, name: 'Um Líder')
      create(:user, :executor, name: 'Um Executor')
      sign_in lider

      get '/users', params: { sort: 'role', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Um Executor')).to be < table.index('Um Líder')
    end

    it 'ignora um parâmetro de ordenação inválido/malicioso e não quebra a página' do
      create(:user, name: 'Usuário qualquer')
      sign_in lider

      get '/users', params: { sort: '1; DROP TABLE users;--', direction: 'asc' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /users/new' do
    it 'bloqueia um executor' do
      sign_in executor
      get '/users/new'
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder acesse o formulário de cadastro' do
      sign_in lider
      get '/users/new'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /users' do
    it 'bloqueia um executor e não cria o usuário' do
      sign_in executor
      expect do
        post '/users', params: novo_usuario_params
      end.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder cadastre um novo usuário com a permissão escolhida' do
      sign_in lider
      expect do
        post '/users', params: novo_usuario_params
      end.to change(User, :count).by(1)
      expect(response).to redirect_to(users_path)

      follow_redirect!
      expect(response.body).to include('alert-dismissible')
      expect(response.body).to include('btn-close')
      expect(User.last.executor?).to be true
    end

    it 'salva o telegram_chat_id quando informado por um admin' do
      sign_in admin
      params = novo_usuario_params.deep_merge(user: { telegram_chat_id: '999888777' })

      post '/users', params: params

      expect(User.last.telegram_chat_id).to eq('999888777')
    end

    it 'ignora o telegram_chat_id quando quem cadastra é líder (não admin)' do
      sign_in lider
      params = novo_usuario_params.deep_merge(user: { telegram_chat_id: '999888777' })

      post '/users', params: params

      expect(User.last.telegram_chat_id).to be_nil
    end
  end

  describe 'GET /users/:id/edit' do
    let!(:outro_usuario) { create(:user, :executor) }

    it 'bloqueia um executor' do
      sign_in executor
      get "/users/#{outro_usuario.id}/edit"
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder acesse a edição de permissões' do
      sign_in lider
      get "/users/#{outro_usuario.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /users/:id' do
    let!(:outro_usuario) { create(:user, :executor) }

    it 'bloqueia um executor e não altera a permissão' do
      sign_in executor
      patch "/users/#{outro_usuario.id}", params: { user: { role: 'lider' } }
      expect(response).to redirect_to(root_path)
      expect(outro_usuario.reload.executor?).to be true
    end

    it 'permite que um líder promova outro usuário a líder' do
      sign_in lider
      patch "/users/#{outro_usuario.id}", params: { user: { role: 'lider' } }
      expect(response).to redirect_to(users_path)
      expect(outro_usuario.reload.lider?).to be true
    end

    it 'permite que um líder rebaixe outro líder para executor' do
      outro_lider = create(:user, :lider)
      sign_in lider
      patch "/users/#{outro_lider.id}", params: { user: { role: 'executor' } }
      expect(outro_lider.reload.executor?).to be true
    end

    it 'permite que um admin cadastre o telegram_chat_id de outro usuário' do
      sign_in admin
      patch "/users/#{outro_usuario.id}", params: { user: { telegram_chat_id: '111222333' } }
      expect(outro_usuario.reload.telegram_chat_id).to eq('111222333')
    end

    it 'rejeita um telegram_chat_id não numérico (enviado por um admin) e não altera o usuário' do
      sign_in admin
      patch "/users/#{outro_usuario.id}", params: { user: { telegram_chat_id: 'não-é-um-numero' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(outro_usuario.reload.telegram_chat_id).to be_nil
    end

    it 'ignora o telegram_chat_id quando quem edita é líder (não admin) — não é um erro, só não altera' do
      sign_in lider
      patch "/users/#{outro_usuario.id}", params: { user: { telegram_chat_id: '111222333' } }
      expect(response).to redirect_to(users_path)
      expect(outro_usuario.reload.telegram_chat_id).to be_nil
    end

    it 'um líder continua conseguindo alterar a permissão, mesmo sem poder tocar no telegram_chat_id' do
      sign_in lider
      patch "/users/#{outro_usuario.id}", params: { user: { role: 'lider', telegram_chat_id: '111222333' } }
      expect(outro_usuario.reload.lider?).to be true
      expect(outro_usuario.telegram_chat_id).to be_nil
    end
  end

  describe 'DELETE /users/:id' do
    let!(:outro_usuario) { create(:user, :executor) }

    it 'bloqueia um executor e não exclui o usuário' do
      sign_in executor
      expect do
        delete "/users/#{outro_usuario.id}"
      end.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder exclua outro usuário' do
      sign_in lider
      expect do
        delete "/users/#{outro_usuario.id}"
      end.to change(User, :count).by(-1)
      expect(response).to redirect_to(users_path)
    end

    it 'impede que o líder exclua o próprio usuário' do
      sign_in lider
      expect do
        delete "/users/#{lider.id}"
      end.not_to change(User, :count)
      expect(response).to redirect_to(users_path)
      expect(flash[:alert]).to match(/não pode excluir o seu próprio usuário/i)
    end

    it 'impede excluir um usuário que já tem demandas cadastradas' do
      create(:demanda, user: outro_usuario)
      sign_in lider

      expect do
        delete "/users/#{outro_usuario.id}"
      end.not_to change(User, :count)
      expect(response).to redirect_to(users_path)
      expect(flash[:alert]).to match(/demandas cadastradas/i)
    end
  end
end
