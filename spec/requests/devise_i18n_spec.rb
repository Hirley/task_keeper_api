# frozen_string_literal: true

require 'rails_helper'

# Regressão para a mensagem "Translation missing" que aparecia ao acessar
# uma tela protegida sem estar logado — faltava config/locales/pt-BR.yml
# com as traduções do Devise (locale padrão da app é pt-BR).
RSpec.describe 'Mensagens do Devise em pt-BR', type: :request do
  it 'mostra uma mensagem traduzida ao tentar acessar uma tela protegida sem login' do
    get '/demandas'

    expect(response).to redirect_to(new_user_session_path)
    follow_redirect!

    expect(response.body).not_to include('Translation missing')
    expect(response.body).to include('Você precisa fazer login ou ser cadastrado por um líder para continuar.')
  end

  it 'mostra uma mensagem traduzida para e-mail/senha inválidos' do
    post '/users/sign_in', params: { user: { email: 'inexistente@task-keeper.local', password: 'errada' } }

    expect(response.body).not_to include('Translation missing')
    expect(response.body).to include('E-mail ou senha inválidos.')
  end
end
