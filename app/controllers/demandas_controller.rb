# Controller web (HAML) para a tela de demandas. Ambos os papéis podem
# criar demandas; apenas o líder pode editar ou excluir uma demanda já
# existente (ver app/models/ability.rb). As ações de editar/excluir só
# aparecem na tela para quem tem permissão (ver app/views/demandas/index.html.haml).
class DemandasController < ApplicationController
  before_action :set_demanda, only: %i[edit update destroy]

  def index
    scope = Demanda.accessible_by(current_ability).includes(:user).order(created_at: :desc)

    @q = params[:q]
    @status_filter = params[:status]
    @demandas = paginate(filter_demandas(scope))
    @title_suggestions = Demanda.distinct.order(:title).limit(50).pluck(:title)
  end

  def new
    authorize! :create, Demanda
    @demanda = Demanda.new
  end

  def create
    authorize! :create, Demanda
    @demanda = current_user.demandas.new(demanda_params)

    if @demanda.save
      redirect_to demandas_path, notice: "Demanda criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @demanda
  end

  def update
    authorize! :update, @demanda

    if @demanda.update(demanda_params)
      redirect_to demandas_path, notice: "Demanda atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @demanda
    @demanda.destroy
    redirect_to demandas_path, notice: "Demanda excluída com sucesso."
  end

  private

  def set_demanda
    @demanda = Demanda.find(params[:id])
  end

  def demanda_params
    params.require(:demanda).permit(:title, :description, :status)
  end

  # Filtro usado na busca da tela de listagem (campo com autocomplete por
  # título + select de status). Ambos são opcionais.
  def filter_demandas(scope)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      scope = scope.where("demandas.title LIKE ?", term)
    end

    if params[:status].present? && Demanda.statuses.key?(params[:status])
      scope = scope.where(status: params[:status])
    end

    scope
  end
end
