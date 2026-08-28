# frozen_string_literal: true

require 'rails_helper'

# Os links de paginação e de ordenação repassam adiante a query string da
# tela atual, pra não perder busca/filtro ao navegar (ver
# ApplicationHelper#query_url). Esse repasse é justamente o que precisa
# ser filtrado: sem limpeza, um parâmetro como ?host=... vira opção de
# roteamento dentro do url_for e sequestra o destino de todos os links.
RSpec.describe 'Links de paginação e ordenação', type: :request do
  let(:lider) { create(:user, :lider) }

  before { sign_in lider }

  describe 'parâmetros de roteamento vindos da query string' do
    before { create(:demanda, user: lider, title: 'Revisar contrato') }

    it 'não deixa ?host= redirecionar os links pra outro domínio' do
      get '/demandas', params: { host: 'evil.com' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('evil.com')
    end

    it 'não deixa ?protocol= nem ?port= reescreverem os links' do
      get '/demandas', params: { protocol: 'javascript', port: '4444' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('javascript:')
      expect(response.body).not_to include(':4444')
    end

    it 'não deixa ?controller= apontar os links pra outra tela' do
      get '/demandas', params: { controller: 'users' }

      expect(response).to have_http_status(:ok)
      # O link de ordenação continua na própria listagem de demandas.
      expect(response.body).to include('/demandas?')
      expect(response.body).not_to include('/users?sort=')
    end
  end

  describe 'preservação dos filtros (o motivo de o repasse existir)' do
    it 'mantém a busca ao trocar a ordenação' do
      create(:demanda, user: lider, title: 'Revisar contrato')

      get '/demandas', params: { q: 'contrato' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('q=contrato')
    end

    it 'mantém a busca nos links de paginação e volta pra página 1 ao reordenar' do
      create_list(:demanda, 11, user: lider, title: 'Revisar contrato')

      get '/demandas', params: { q: 'contrato' }

      expect(response.body).to include('page=2')
      expect(response.body).to include('q=contrato')
      # sort_header zera a paginação — 'page' => nil sai da URL.
      expect(response.body).not_to match(/sort=title[^"]*page=/)
    end
  end
end
