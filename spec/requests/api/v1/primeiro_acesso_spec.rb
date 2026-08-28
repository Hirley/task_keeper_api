# frozen_string_literal: true

require 'rails_helper'

# Ver ExigeTrocaDeSenha. A regra de primeiro acesso vivia só no
# ApplicationController, e Api::V1::BaseController herda de
# ActionController::Base — então a API inteira ficava de fora: o usuário
# era barrado em toda tela do site e, ao mesmo tempo, criava demandas e
# listava usuários normalmente por aqui, com uma senha provisória que
# quem a cadastrou também conhece.
RSpec.describe 'Api::V1 primeiro acesso', type: :request do
  let(:lider_novo) { create(:user, :lider, :primeiro_acesso) }
  let(:lider) { create(:user, :lider) }

  describe 'usuário ainda com a senha provisória' do
    before { sign_in lider_novo }

    it 'recusa a leitura com 403' do
      get '/api/v1/demandas'

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to include('senha')
    end

    it 'recusa a escrita com 403 e não cria nada' do
      expect do
        post '/api/v1/demandas',
             params: { demanda: { title: 'Revisar contrato', data: Date.current } },
             as: :json
      end.not_to change(Demanda, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'recusa a listagem de usuários com 403' do
      get '/api/v1/users'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'usuário que já definiu a própria senha' do
    before { sign_in lider }

    it 'usa a API normalmente' do
      get '/api/v1/demandas'

      expect(response).to have_http_status(:ok)
    end
  end
end
