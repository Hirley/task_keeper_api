# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Busca global (navbar)', type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe 'GET /busca' do
    it 'encontra demandas pelo título, pro líder e pro executor' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      sign_in executor

      get '/busca', params: { q: 'contrato' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Revisar contrato')
    end

    it 'encontra usuários pelo nome/e-mail só pro líder (executor não gerencia Acessos)' do
      create(:user, name: 'Fulano de Tal', email: 'fulano@example.com')
      sign_in lider

      get '/busca', params: { q: 'fulano' }

      expect(response.body).to include('Fulano de Tal')
    end

    it 'não mostra usuários na busca do executor, mesmo com termo compatível' do
      create(:user, name: 'Fulano de Tal', email: 'fulano@example.com')
      sign_in executor

      get '/busca', params: { q: 'fulano' }

      expect(response.body).to include('Nada encontrado')
      expect(response.body).not_to include('Fulano de Tal')
    end

    it 'sem termo de busca, não lista nada' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      sign_in lider

      get '/busca'

      expect(response.body).not_to include('Revisar contrato')
    end
  end

  describe 'GET /busca.json' do
    it 'devolve demandas e usuários (pro líder) em JSON, com link pra listagem filtrada' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      create(:user, name: 'Fulano de Tal', email: 'fulano@example.com')
      sign_in lider

      get '/busca.json', params: { q: 'a' }

      json = response.parsed_body
      expect(json['demandas']).to include(a_hash_including('title' => 'Revisar contrato'))
      expect(json['users']).to include(a_hash_including('title' => 'Fulano de Tal', 'subtitle' => 'fulano@example.com'))
    end

    it 'devolve só demandas pro executor (sem vazar usuários)' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      create(:user, name: 'Fulano de Tal', email: 'fulano@example.com')
      sign_in executor

      get '/busca.json', params: { q: 'a' }

      json = response.parsed_body
      expect(json['demandas']).not_to be_empty
      expect(json['users']).to eq([])
    end
  end
end
