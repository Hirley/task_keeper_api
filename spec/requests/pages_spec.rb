# frozen_string_literal: true

require 'rails_helper'

# A página de acessibilidade precisa funcionar mesmo sem login (ver
# app/controllers/pages_controller.rb) — alguém pode precisar dela
# justamente para conseguir enxergar/operar a própria tela de login.
#
# Os recursos de fonte/alto-contraste em si são só JS (ver
# app/javascript/application.js) e, como o restante do projeto, não têm
# cobertura automatizada porque o Gemfile não inclui um driver
# Capybara/JS (mesma situação já documentada para outras interações só-JS
# do app).
RSpec.describe 'Página de acessibilidade', type: :request do
  it 'responde sem exigir autenticação' do
    get '/acessibilidade'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Acessibilidade')
  end

  it 'continua acessível para um usuário autenticado' do
    sign_in create(:user)

    get '/acessibilidade'

    expect(response).to have_http_status(:ok)
  end
end
