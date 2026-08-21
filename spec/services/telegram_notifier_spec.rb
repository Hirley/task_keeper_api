# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

RSpec.describe TelegramNotifier do
  # Dublê simples do transporte HTTP: evita depender de uma gem de mock de
  # rede (o Gemfile não tem WebMock/VCR) e evita qualquer chamada de rede
  # real nos testes. Guarda cada chamada para os testes inspecionarem.
  subject(:notifier) { described_class.new(bot_token: 'token-de-teste', transport: transport) }

  let(:chamadas) { [] }
  let(:resposta_sucesso) { Net::HTTPOK.allocate }
  let(:resposta_falha) { Net::HTTPBadRequest.allocate }
  let(:transport) do
    lambda { |uri, body|
      chamadas << { uri: uri, body: body }
      resposta_sucesso
    }
  end

  let(:lider) { build_stubbed(:user, :executor, name: 'Ana Paula Souza', telegram_chat_id: '555111222') }
  let(:demanda) do
    build_stubbed(:demanda, title: 'Revisar contrato', data: 3.days.ago.to_date, user: lider)
  end

  describe '#notify_atraso' do
    it 'envia a mensagem para o chat_id do responsável pela demanda' do
      notifier.notify_atraso(demanda)

      expect(chamadas.size).to eq(1)
      expect(chamadas.first[:body]).to include('"chat_id":"555111222"')
    end

    it 'usa a URL da API do Telegram com o token configurado' do
      notifier.notify_atraso(demanda)

      expect(chamadas.first[:uri].to_s).to eq('https://api.telegram.org/bottoken-de-teste/sendMessage')
    end

    it 'monta uma mensagem empática e objetiva, citando o título e os dias de atraso' do
      notifier.notify_atraso(demanda)

      texto = JSON.parse(chamadas.first[:body])['text']
      expect(texto).to include('Ana Paula Souza')
      expect(texto).to include('Revisar contrato')
      expect(texto).to include('3 dias')
      # "cobrança" fica de fora da lista de palavras proibidas de propósito:
      # a própria mensagem usa "Sem cobrança" para tranquilizar o executor.
      # O que não pode aparecer é tom de urgência/cobrança de fato (ex.:
      # "urgente", "inaceitável", "cobrando").
      expect(texto).not_to match(/urgente|inaceitável|cobrando/i)
      expect(texto).to include('Sem cobrança')
    end

    it 'retorna true quando o Telegram responde com sucesso' do
      expect(notifier.notify_atraso(demanda)).to be true
    end

    it 'retorna false quando o Telegram responde com erro' do
      transport_com_falha = ->(_uri, _body) { resposta_falha }
      notifier = described_class.new(bot_token: 'token-de-teste', transport: transport_com_falha)

      expect(notifier.notify_atraso(demanda)).to be false
    end

    it 'não envia nada e retorna false quando não há TELEGRAM_BOT_TOKEN configurado' do
      notifier = described_class.new(bot_token: nil, transport: transport)

      expect(notifier.notify_atraso(demanda)).to be false
      expect(chamadas).to be_empty
    end

    it 'não envia nada e retorna false quando o responsável não tem telegram_chat_id' do
      demanda_sem_chat_id = build_stubbed(:demanda, user: build_stubbed(:user, telegram_chat_id: nil))

      expect(notifier.notify_atraso(demanda_sem_chat_id)).to be false
      expect(chamadas).to be_empty
    end

    it 'não propaga exceção se o transporte falhar (ex.: rede fora do ar) e retorna false' do
      transport_com_erro = ->(_uri, _body) { raise SocketError, 'falha de rede' }
      notifier = described_class.new(bot_token: 'token-de-teste', transport: transport_com_erro)

      expect(notifier.notify_atraso(demanda)).to be false
    end
  end

  describe '.notify_atraso' do
    it 'delega para uma instância nova, usando ENV["TELEGRAM_BOT_TOKEN"] por padrão' do
      original_token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
      ENV['TELEGRAM_BOT_TOKEN'] = nil

      expect(described_class.notify_atraso(demanda)).to be false
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = original_token
    end
  end

  describe '#enviar_documento' do
    let(:documento_chamadas) { [] }
    let(:document_transport) do
      lambda do |uri, chat_id, filename, conteudo, legenda|
        documento_chamadas << { uri: uri, chat_id: chat_id, filename: filename, conteudo: conteudo, legenda: legenda }
        resposta_sucesso
      end
    end
    let(:notifier_com_documento) do
      described_class.new(bot_token: 'token-de-teste', transport: transport, document_transport: document_transport)
    end

    it 'envia o arquivo pro chat_id do usuário, via sendDocument' do
      notifier_com_documento.enviar_documento(lider, filename: 'relatorio.pdf', conteudo: '%PDF-conteudo-fake',
                                                     legenda: 'Relatório semanal')

      expect(documento_chamadas.size).to eq(1)
      chamada = documento_chamadas.first
      expect(chamada[:uri].to_s).to eq('https://api.telegram.org/bottoken-de-teste/sendDocument')
      expect(chamada[:chat_id]).to eq('555111222')
      expect(chamada[:filename]).to eq('relatorio.pdf')
      expect(chamada[:conteudo]).to eq('%PDF-conteudo-fake')
      expect(chamada[:legenda]).to eq('Relatório semanal')
    end

    it 'retorna true quando o Telegram responde com sucesso' do
      resultado = notifier_com_documento.enviar_documento(lider, filename: 'relatorio.pdf', conteudo: 'x')

      expect(resultado).to be true
    end

    it 'não envia nada e retorna false sem TELEGRAM_BOT_TOKEN configurado' do
      notifier = described_class.new(bot_token: nil, document_transport: document_transport)

      expect(notifier.enviar_documento(lider, filename: 'relatorio.pdf', conteudo: 'x')).to be false
      expect(documento_chamadas).to be_empty
    end

    it 'não envia nada e retorna false quando o usuário não tem telegram_chat_id' do
      usuario_sem_chat_id = build_stubbed(:user, telegram_chat_id: nil)

      resultado = notifier_com_documento.enviar_documento(usuario_sem_chat_id, filename: 'relatorio.pdf', conteudo: 'x')

      expect(resultado).to be false
      expect(documento_chamadas).to be_empty
    end

    it 'não propaga exceção se o transporte falhar e retorna false' do
      transport_com_erro = ->(_uri, _chat_id, _filename, _conteudo, _legenda) { raise SocketError, 'falha de rede' }
      notifier = described_class.new(bot_token: 'token-de-teste', document_transport: transport_com_erro)

      expect(notifier.enviar_documento(lider, filename: 'relatorio.pdf', conteudo: 'x')).to be false
    end
  end
end
