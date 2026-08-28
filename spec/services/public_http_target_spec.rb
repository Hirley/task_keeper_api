# frozen_string_literal: true

require 'rails_helper'

# Todos os casos usam IP literal: Resolv resolve um literal sem consultar
# DNS de verdade, então o spec não depende de rede externa (mesma razão
# documentada em spec/factories/webhook_subscriptions.rb).
RSpec.describe PublicHttpTarget do
  describe '.resolve' do
    context 'com uma URL pública válida' do
      subject(:resultado) { described_class.resolve('https://8.8.8.8/hook') }

      it { is_expected.to be_success }

      it 'devolve o IP verificado, pra quem for conectar não resolver de novo' do
        expect(resultado.ip).to eq('8.8.8.8')
      end

      it 'devolve a URI parseada' do
        expect(resultado.uri.to_s).to eq('https://8.8.8.8/hook')
      end
    end

    context 'com endereço de rede interna' do
      it 'recusa loopback IPv4' do
        expect(described_class.resolve('http://127.0.0.1/hook').error_code).to eq(:endereco_privado)
      end

      it 'recusa loopback IPv6 escrito com colchetes' do
        expect(described_class.resolve('http://[::1]/hook').error_code).to eq(:endereco_privado)
      end

      it 'recusa rede privada (10.x)' do
        expect(described_class.resolve('http://10.0.0.5/hook').error_code).to eq(:endereco_privado)
      end

      it 'recusa rede privada (192.168.x)' do
        expect(described_class.resolve('http://192.168.1.10/hook').error_code).to eq(:endereco_privado)
      end

      it 'recusa link-local (metadata de nuvem)' do
        expect(described_class.resolve('http://169.254.169.254/latest/meta-data').error_code)
          .to eq(:endereco_privado)
      end
    end

    context 'com URL inválida' do
      it 'recusa texto que não é URL' do
        expect(described_class.resolve('não é uma url').error_code).to eq(:url_invalida)
      end

      it 'recusa esquema que não é http(s)' do
        expect(described_class.resolve('ftp://8.8.8.8/hook').error_code).to eq(:url_invalida)
      end

      it 'recusa URL sem host' do
        expect(described_class.resolve('http:///hook').error_code).to eq(:url_invalida)
      end

      it 'recusa nil' do
        expect(described_class.resolve(nil).error_code).to eq(:url_invalida)
      end
    end

    context 'quando a resolução de DNS não responde' do
      it 'não fica pendurado além do timeout e recusa como host não resolvido' do
        allow(Resolv).to receive(:getaddresses).and_raise(Timeout::Error)

        expect(described_class.resolve('https://exemplo.test/hook').error_code).to eq(:host_nao_resolvido)
      end

      it 'trata host inexistente como host não resolvido' do
        allow(Resolv).to receive(:getaddresses).and_return([])

        expect(described_class.resolve('https://exemplo.test/hook').error_code).to eq(:host_nao_resolvido)
      end
    end
  end
end
