# frozen_string_literal: true

require 'rails_helper'

# Ver config/initializers/content_security_policy.rb. O valor do CSP está
# quase todo em "o que NÃO pode": por isso os exemplos abaixo verificam
# ausências, não presenças. Uma diretiva afrouxada não quebra nenhuma tela
# — o app continua funcionando perfeitamente com script-src 'unsafe-inline'
# —, então sem um teste explícito a proteção some sem ninguém notar.
RSpec.describe 'Content Security Policy', type: :request do
  let(:usuario) { create(:user, :lider) }
  let(:politica) { response.headers['Content-Security-Policy'] }

  before do
    sign_in usuario
    get root_path
  end

  it 'envia o header em toda resposta HTML' do
    expect(response).to have_http_status(:ok)
    expect(politica).to be_present
  end

  describe 'script-src' do
    let(:script_src) { politica[/script-src [^;]+/] }

    # O ponto do PR inteiro. Com 'unsafe-inline' aqui, um XSS armazenado
    # injetaria <script> à vontade e o resto da política viraria enfeite.
    it 'não libera unsafe-inline nem unsafe-eval' do
      expect(script_src).not_to include('unsafe-inline')
      expect(script_src).not_to include('unsafe-eval')
    end

    # Estável dentro da sessão, de propósito — ver o comentário no
    # initializer. Nonce novo a cada resposta quebra a navegação do Turbo
    # Drive, que mantém em vigor o CSP da primeira página carregada.
    it 'usa nonce, estável dentro da mesma sessão' do
      expect(script_src).to match(/'nonce-[^']+'/)

      primeiro = script_src[/'nonce-[^']+'/]
      get root_path
      expect(response.headers['Content-Security-Policy'][/'nonce-[^']+'/]).to eq(primeiro)
    end

    it 'permite só as origens de terceiro que o layout de fato carrega' do
      expect(script_src).to include("'self'", 'https://cdn.jsdelivr.net', 'https://vlibras.gov.br')
    end
  end

  it 'fecha object-src, frame-ancestors, base-uri e form-action' do
    expect(politica).to include("object-src 'none'")
    expect(politica).to include("frame-ancestors 'none'")
    expect(politica).to include("base-uri 'self'")
    expect(politica).to include("form-action 'self'")
  end

  # Guarda estrutural: atributo de evento inline não executa sob esta
  # política, e nonce não cobre atributo (só tag <script>). Se alguém
  # reintroduzir um onclick numa view, a tela quebra silenciosamente no
  # navegador — aqui quebra no CI. Ver a delegação por data-tk-action no
  # fim de app/javascript/application.js.
  it 'não renderiza nenhum atributo de evento inline' do
    expect(response.body).not_to match(/\son(click|change|submit|load|error)=/)
  end

  # Ver os hashes em app/views/layouts/application.html.haml. Sem SRI, um
  # comprometimento do CDN entrega JavaScript arbitrário para dentro de uma
  # origem que o CSP autoriza — o SRI é o que fecha essa porta.
  it 'carrega os arquivos do jsDelivr com integrity e crossorigin' do
    tags_jsdelivr = response.body.scan(/<(?:link|script)[^>]*cdn\.jsdelivr\.net[^>]*>/)

    expect(tags_jsdelivr.size).to eq(2)
    expect(tags_jsdelivr).to all(include('integrity="sha384-').and(include('crossorigin="anonymous"')))
  end
end
