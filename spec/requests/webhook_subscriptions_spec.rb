# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks (tela web)', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe "item 'Webhooks' no menu" do
    it 'aparece pro admin' do
      sign_in admin
      get '/'
      expect(response.body).to include('>Webhooks<')
    end

    it 'não aparece pro líder' do
      sign_in lider
      get '/'
      expect(response.body).not_to include('>Webhooks<')
    end

    it 'não aparece pro executor' do
      sign_in executor
      get '/'
      expect(response.body).not_to include('>Webhooks<')
    end
  end

  describe 'GET /webhooks' do
    it 'lista os webhooks cadastrados pro admin' do
      create(:webhook_subscription, url: 'http://8.8.8.8/hook', user: admin)
      sign_in admin

      get '/webhooks'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('http://8.8.8.8/hook')
    end

    it 'bloqueia um líder (webhooks são exclusivos do admin)' do
      sign_in lider

      get '/webhooks'

      expect(response).to redirect_to(root_path)
    end

    it 'bloqueia um executor' do
      sign_in executor

      get '/webhooks'

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /webhooks' do
    it 'cadastra um webhook com os eventos escolhidos' do
      sign_in admin

      post '/webhooks', params: {
        webhook_subscription: { url: 'http://8.8.8.8/hook', events: %w[demanda_criada demanda_concluida] }
      }

      expect(response).to redirect_to(webhook_subscriptions_path)
      webhook = WebhookSubscription.last
      expect(webhook.url).to eq('http://8.8.8.8/hook')
      expect(webhook.events).to contain_exactly('demanda_criada', 'demanda_concluida')
      expect(webhook.user).to eq(admin)
    end

    it 'rejeita uma URL apontando pra um endereço privado/local' do
      sign_in admin

      post '/webhooks', params: { webhook_subscription: { url: 'http://127.0.0.1/hook', events: %w[demanda_criada] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(WebhookSubscription.count).to eq(0)
    end

    it 'bloqueia um líder e não cria o webhook' do
      sign_in lider

      post '/webhooks', params: { webhook_subscription: { url: 'http://8.8.8.8/hook', events: %w[demanda_criada] } }

      expect(response).to redirect_to(root_path)
      expect(WebhookSubscription.count).to eq(0)
    end

    it 'bloqueia um executor e não cria o webhook' do
      sign_in executor

      post '/webhooks', params: { webhook_subscription: { url: 'http://8.8.8.8/hook', events: %w[demanda_criada] } }

      expect(response).to redirect_to(root_path)
      expect(WebhookSubscription.count).to eq(0)
    end
  end

  describe 'PATCH /webhooks/:id' do
    it 'atualiza os eventos e permite pausar (active: false)' do
      webhook = create(:webhook_subscription, events: %w[demanda_criada], user: admin)
      sign_in admin

      patch "/webhooks/#{webhook.id}", params: { webhook_subscription: { events: %w[relatorio_gerado], active: false } }

      expect(response).to redirect_to(webhook_subscriptions_path)
      webhook.reload
      expect(webhook.events).to contain_exactly('relatorio_gerado')
      expect(webhook.active).to be false
    end
  end

  describe 'DELETE /webhooks/:id' do
    it 'remove o webhook' do
      webhook = create(:webhook_subscription, user: admin)
      sign_in admin

      expect { delete "/webhooks/#{webhook.id}" }.to change(WebhookSubscription, :count).by(-1)
      expect(response).to redirect_to(webhook_subscriptions_path)
    end

    it 'pede confirmação antes de excluir' do
      create(:webhook_subscription, user: admin)
      sign_in admin

      get '/webhooks'

      expect(response.body).to include('data-turbo-confirm')
    end
  end
end
