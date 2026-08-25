# frozen_string_literal: true

# Busca global (barra de busca na navbar — ver
# app/views/layouts/application.html.haml e app/javascript/application.js
# pro dropdown com sugestões em tempo real + busca por voz). Cobre só
# Demandas e Acessos (os dois recursos com listagem própria); Relatórios
# não tem itens individuais pra buscar.
#
# Os resultados apontam para a listagem já filtrada (demandas_path/users_path
# com "q="), não uma página de detalhe — Demanda nem tem "show" (só
# index/edit), e reaproveitar o filtro existente evita duplicar a lógica de
# permissão (accessible_by/can?) numa segunda página.
class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip

    @demandas = buscar_demandas
    @users = buscar_users

    respond_to do |format|
      format.html
      format.json { render json: resultados_json }
    end
  end

  private

  def buscar_demandas
    return Demanda.none if @q.blank?

    Demanda.accessible_by(current_ability).ransack(title_cont: @q).result.order(:title).limit(8)
  end

  # Só líder busca em Acessos (mesma regra de quem vê o menu "Acessos" —
  # ver app/models/ability.rb e can? :manage, User na navbar).
  def buscar_users
    return User.none if @q.blank? || cannot?(:manage, User)

    User.ransack(name_or_email_cont: @q).result.order(:name).limit(8)
  end

  def resultados_json
    {
      demandas: @demandas.map { |demanda| { title: demanda.title, url: demandas_path(q: demanda.title) } },
      users: @users.map { |user| { title: user.name, subtitle: user.email, url: users_path(q: user.name) } }
    }
  end
end
