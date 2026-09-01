# frozen_string_literal: true

require 'rails_helper'

# A única cobertura de navegador do projeto, e ela é deliberadamente
# pequena: não replica o que os request specs já verificam. Cobre os
# lugares onde a falha é SILENCIOSA — a página continua renderizando, o
# servidor continua respondendo 200, e só o navegador sabe que algo foi
# bloqueado ou deixou de rodar.
#
# O custo de não ter isto não é teórico. A CSP introduzida na v2.0.0
# precisou ser corrigida duas vezes por comportamento que só aparece num
# navegador de verdade: o widget do VLibras carregando imagem de outro
# CDN, e o nonce por requisição quebrando a navegação do Turbo Drive.
# Nenhuma das duas quebraria um spec de request.
RSpec.describe 'Navegador', type: :system do
  # tour_completed_at preenchido de propósito: o tour guiado dispara
  # sozinho no painel de quem nunca o completou (ver
  # app/views/dashboard/index.html.haml), e o overlay dele cobre a tela
  # inteira, interceptando qualquer clique. Quem estes exemplos
  # representam é o usuário do dia a dia, que já passou por ele.
  #
  # Isso só ficou visível aqui: com um navegador de verdade o overlay
  # existe e intercepta; num request spec ele é só markup no HTML.
  let(:usuario) { create(:user, :lider, tour_completed_at: 1.day.ago) }

  describe 'política de CSP' do
    it 'carrega a página pública sem nenhuma violação' do
      visit acessibilidade_path

      expect(page).to have_css('h1')
      expect(violacoes_de_csp).to be_empty
    end

    it 'carrega uma página autenticada sem nenhuma violação' do
      login_as(usuario, scope: :user)

      visit root_path

      expect(page).to have_css('.tk-a11y-bar')
      expect(violacoes_de_csp).to be_empty
    end

    # O caso que já quebrou. O Turbo troca o <body> sem criar documento
    # novo, então continua valendo o CSP da PRIMEIRA resposta — um nonce
    # diferente na segunda página é bloqueado por uma política que não o
    # conhece. Ver o comentário em config/initializers/content_security_policy.rb.
    it 'continua sem violações depois de uma navegação do Turbo Drive' do
      login_as(usuario, scope: :user)
      visit root_path
      violacoes_de_csp # drena o que veio da primeira página

      click_link 'Demandas'

      expect(page).to have_current_path(demandas_path)
      expect(violacoes_de_csp).to be_empty
    end
  end

  # Estes dois não olham o console: olham o efeito. Se o nonce do
  # importmap fosse recusado, application.js não rodaria e nada abaixo
  # aconteceria — a página continuaria bonita e inerte, que é o modo de
  # falha que um request spec não enxerga.
  describe 'JavaScript da aplicação' do
    before { login_as(usuario, scope: :user) }

    it 'alterna o alto contraste, e o estado sobrevive à navegação do Turbo' do
      visit root_path

      find('#tk-contrast-toggle').click
      expect(page).to have_css('html.tk-high-contrast')

      click_link 'Demandas'

      expect(page).to have_current_path(demandas_path)
      # O <html> não é recriado pelo Turbo, mas o botão é — e é o
      # application.js que precisa reaplicar o estado guardado.
      expect(page).to have_css('html.tk-high-contrast')
      expect(page).to have_css('#tk-contrast-toggle[aria-pressed="true"]')
    end

    it 'pede confirmação do Turbo antes de excluir uma demanda' do
      demanda = create(:demanda, title: 'Demanda a excluir')
      visit demandas_path

      accept_confirm('Tem certeza que deseja excluir esta demanda?') do
        find("form[action='#{demanda_path(demanda)}'] button").click
      end

      expect(page).to have_content('Demanda excluída com sucesso.')
      expect(Demanda.exists?(demanda.id)).to be false
    end
  end
end
