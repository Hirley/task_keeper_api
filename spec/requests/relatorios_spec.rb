# frozen_string_literal: true

require 'rails_helper'

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

    # O envio saiu da requisição (ver RelatorioSemanalTelegramJob), então
    # o que a tela deve garantir aqui é: enfileirou, respondeu na hora e
    # não gerou o PDF nem tocou na rede no caminho.
    it 'enfileira o envio e responde na hora, sem gerar o PDF dentro da requisição' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = 'token-de-teste'
      lider.update!(telegram_chat_id: '111222333')
      allow(Relatorios::GerarPdfSemanal).to receive(:call)

      sign_in lider

      expect { post '/relatorios/enviar_telegram' }
        .to have_enqueued_job(RelatorioSemanalTelegramJob).with(lider.id)
      expect(Relatorios::GerarPdfSemanal).not_to have_received(:call)
      expect(response).to redirect_to(relatorios_path)
      follow_redirect!
      expect(response.body).to include('Ele chega no seu Telegram em instantes.')
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end

    # Os dois motivos previsíveis de falha (sem token no servidor, sem
    # Chat ID no usuário) continuam sendo decididos na tela — é o que
    # permite manter a mensagem de erro útil mesmo com o envio assíncrono.
    # Ver RelatoriosController#enviar_telegram.
    it 'mostra uma mensagem de erro clara e não enfileira nada quando falta configuração' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = nil
      sign_in lider

      expect { post '/relatorios/enviar_telegram' }
        .not_to have_enqueued_job(RelatorioSemanalTelegramJob)

      expect(response).to redirect_to(relatorios_path)
      follow_redirect!
      expect(response.body).to include('Não foi possível enviar pelo Telegram.')
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end

    it 'não enfileira nada quando o líder não tem Chat ID do Telegram cadastrado' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = 'token-de-teste'
      lider.update!(telegram_chat_id: nil)
      sign_in lider

      expect { post '/relatorios/enviar_telegram' }
        .not_to have_enqueued_job(RelatorioSemanalTelegramJob)
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end
  end
end
