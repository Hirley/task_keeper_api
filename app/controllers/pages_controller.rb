# frozen_string_literal: true

# Páginas informativas/estáticas que não fazem parte do fluxo de
# demandas/usuários. A página de acessibilidade fica acessível mesmo sem
# login — alguém pode precisar dela justamente para conseguir enxergar ou
# operar a tela de login (ver app/views/layouts/application.html.haml,
# onde a barra de acessibilidade já aparece antes do login também).
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :acessibilidade

  def acessibilidade; end
end
