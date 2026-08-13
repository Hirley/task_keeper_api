# Controller web (HAML) apenas para listagem das demandas visíveis ao
# usuário autenticado. A criação/edição/exclusão acontece via API (api/v1).
class DemandasController < ApplicationController
  def index
    @demandas = Demanda.accessible_by(current_ability).includes(:user).order(created_at: :desc)
  end
end
