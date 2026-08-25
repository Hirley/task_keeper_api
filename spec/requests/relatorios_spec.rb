# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

RSpec.describe 'Relatório semanal (tela web)', type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe "item 'Relatórios' no menu" do
    it 'aparece pro líder' do
      sign_in lider
      get '/'
      expect(response.body).to include('>Relatórios<')
    end

    it 'não aparece pro executor' do
      sign_in executor
      get '/'
      expect(response.body).not_to include('>Relatórios<')
    end
  end

  describe 'GET /relatorios' do
    it 'bloqueia um executor' do
      sign_in executor
      get '/relatorios'
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder veja o relatório' do
      create(:demanda, user: lider)
      sign_in lider

      get '/relatorios'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Relatório semanal')
    end

    it 'não dispara o webhook "relatorio_gerado" só de visitar a pré-visualização' do
      sign_in lider
      allow(WebhookDispatcher).to receive(:dispatch)

      get '/relatorios'

      expect(WebhookDispatcher).not_to have_received(:dispatch)
    end
  end

  describe 'GET /relatorios/semanal.pdf' do
    it 'bloqueia um executor' do
      sign_in executor
      get '/relatorios/semanal.pdf'
      expect(response).to redirect_to(root_path)
    end

    it 'devolve um PDF pro líder' do
      create(:demanda, user: lider)
      sign_in lider

      get '/relatorios/semanal.pdf'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
    end

    it 'dispara o webhook "relatorio_gerado" quando o PDF é efetivamente baixado' do
      create(:demanda, user: lider)
      sign_in lider
      allow(WebhookDispatcher).to receive(:dispatch)

      get '/relatorios/semanal.pdf'

      expect(WebhookDispatcher).to have_received(:dispatch)
        .with('relatorio_gerado', hash_including(:periodo_inicio, :periodo_fim))
    end
  end

  describe 'POST /relatorios/enviar_telegram' do
    it 'bloqueia um executor' do
      sign_in executor
      post '/relatorios/enviar_telegram'
      expect(response).to redirect_to(root_path)
    end

    it 'envia o PDF pro Telegram do próprio líder e mostra uma mensagem de sucesso' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = 'token-de-teste'
      lider.update!(telegram_chat_id: '111222333')

      chamadas = []
      transport = lambda do |uri, chat_id, filename, _conteudo, legenda|
        chamadas << { uri: uri, chat_id: chat_id, filename: filename, legenda: legenda }
        Net::HTTPOK.allocate
      end
      # Substitui TelegramNotifier.new por uma instância com o transporte
      # dublê injetado, pra este request spec não fazer nenhuma chamada de
      # rede real (RelatoriosController#enviar_telegram chama
      # `TelegramNotifier.new` sem argumentos — ver app/controllers/relatorios_controller.rb).
      allow(TelegramNotifier).to receive(:new).and_return(TelegramNotifier.new(document_transport: transport))

      sign_in lider
      post '/relatorios/enviar_telegram'

      expect(response).to redirect_to(relatorios_path)
      follow_redirect!
      expect(response.body).to include('Relatório enviado no seu Telegram.')
      expect(chamadas.size).to eq(1)
      expect(chamadas.first[:chat_id]).to eq('111222333')
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end

    it 'mostra uma mensagem de erro clara quando não é possível enviar (ex.: sem chat_id cadastrado)' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = nil
      sign_in lider

      post '/relatorios/enviar_telegram'

      expect(response).to redirect_to(relatorios_path)
      follow_redirect!
      expect(response.body).to include('Não foi possível enviar pelo Telegram.')
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end
  end
end
