# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Demandas', type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe 'GET /api/v1/demandas' do
    before { create_list(:demanda, 2, user: executor) }

    it 'exige autenticação' do
      get '/api/v1/demandas'
      expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
    end

    it 'lista demandas para um usuário autenticado' do
      sign_in executor
      get '/api/v1/demandas'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(2)
    end
  end

  describe 'POST /api/v1/demandas' do
    it 'permite que um executor crie uma demanda' do
      sign_in executor
      expect do
        post '/api/v1/demandas', params: { demanda: { title: 'Nova demanda' } }, as: :json
      end.to change(Demanda, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'permite que um líder crie uma demanda' do
      sign_in lider
      expect do
        post '/api/v1/demandas', params: { demanda: { title: 'Nova demanda' } }, as: :json
      end.to change(Demanda, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'usa a data de hoje por padrão quando nenhuma data é enviada' do
      sign_in executor
      post '/api/v1/demandas', params: { demanda: { title: 'Nova demanda' } }, as: :json
      expect(Demanda.last.data).to eq(Date.current)
    end

    it 'permite que um executor escolha outra data ao criar' do
      outra_data = 5.days.from_now.to_date
      sign_in executor
      post '/api/v1/demandas', params: { demanda: { title: 'Nova demanda', data: outra_data } }, as: :json
      expect(Demanda.last.data).to eq(outra_data)
    end
  end

  describe 'PATCH /api/v1/demandas/:id' do
    let!(:demanda) { create(:demanda, user: lider) }

    it 'bloqueia um executor com 403' do
      sign_in executor
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { title: 'Alterada' } }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(demanda.reload.title).not_to eq('Alterada')
    end

    it 'permite que um líder atualize a demanda' do
      sign_in lider
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { title: 'Alterada' } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(demanda.reload.title).to eq('Alterada')
    end

    it 'bloqueia um executor tentando alterar a data com 403' do
      outra_data = 10.days.from_now.to_date
      sign_in executor
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { data: outra_data } }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(demanda.reload.data).not_to eq(outra_data)
    end

    it 'permite que um líder altere a data de uma demanda já cadastrada' do
      outra_data = 10.days.from_now.to_date
      sign_in lider
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { data: outra_data } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(demanda.reload.data).to eq(outra_data)
    end
  end

  describe 'Content-Type exigido em ações de escrita (proteção contra CSRF)' do
    let!(:demanda) { create(:demanda, user: lider) }

    # A API desativa o token CSRF (ver Api::V1::BaseController) por
    # autenticar via sessão; o que fecha a brecha é exigir
    # Content-Type: application/json, já que um <form> HTML comum (o vetor
    # clássico de CSRF) nunca consegue enviar esse Content-Type — só
    # application/x-www-form-urlencoded, multipart/form-data ou
    # text/plain. Por isso os testes abaixo simulam exatamente isso: uma
    # requisição SEM `as: :json` (o padrão do helper de teste do Rails já
    # é form-encoded).
    it 'rejeita POST sem Content-Type: application/json com 415' do
      sign_in executor
      expect do
        post '/api/v1/demandas', params: { demanda: { title: 'Nova demanda' } }
      end.not_to change(Demanda, :count)
      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'rejeita PATCH sem Content-Type: application/json com 415' do
      sign_in lider
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { title: 'Alterada via form' } }
      expect(response).to have_http_status(:unsupported_media_type)
      expect(demanda.reload.title).not_to eq('Alterada via form')
    end

    it 'rejeita DELETE sem Content-Type: application/json com 415 (inclusive sem corpo)' do
      sign_in lider
      expect do
        delete "/api/v1/demandas/#{demanda.id}"
      end.not_to change(Demanda, :count)
      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'não afeta GET (leitura continua liberada sem exigir Content-Type)' do
      sign_in executor
      get '/api/v1/demandas'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/demandas/:id' do
    let!(:demanda) { create(:demanda, user: lider) }

    it 'bloqueia um executor com 403' do
      sign_in executor
      expect do
        delete "/api/v1/demandas/#{demanda.id}", as: :json
      end.not_to change(Demanda, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'permite que um líder exclua a demanda' do
      sign_in lider
      expect do
        delete "/api/v1/demandas/#{demanda.id}", as: :json
      end.to change(Demanda, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    # Mesmo caso do spec da tela web: nenhum impeditivo existe hoje, então
    # o bloqueio é simulado. O que se verifica é que a API olha o retorno
    # de #destroy antes de responder 204.
    it 'responde 422 com os erros quando a exclusão é bloqueada' do
      bloqueada = Demanda.find(demanda.id)
      bloqueada.errors.add(:base, 'Existe um apontamento vinculado a esta demanda.')
      allow(Demanda).to receive(:find).and_return(bloqueada)
      allow(bloqueada).to receive(:destroy).and_return(false)

      sign_in lider
      expect do
        delete "/api/v1/demandas/#{demanda.id}", as: :json
      end.not_to change(Demanda, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('Existe um apontamento vinculado a esta demanda.')
    end

    it 'devolve uma mensagem genérica quando a exclusão falha sem popular errors' do
      bloqueada = Demanda.find(demanda.id)
      allow(Demanda).to receive(:find).and_return(bloqueada)
      allow(bloqueada).to receive(:destroy).and_return(false)

      sign_in lider
      delete "/api/v1/demandas/#{demanda.id}", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to eq(['Não foi possível excluir a demanda.'])
    end
  end
end
