# Controller web (HAML) para a tela de demandas. Ambos os papéis podem
# criar demandas; apenas o líder pode editar ou excluir uma demanda já
# existente (ver app/models/ability.rb). As ações de editar/excluir só
# aparecem na tela para quem tem permissão (ver app/views/demandas/index.html.haml).
class DemandasController < ApplicationController
  before_action :set_demanda, only: %i[edit update destroy]

  # Colunas que podem ser usadas para ordenar a listagem (whitelist —
  # nunca interpolar params[:sort] direto numa query). A chave é o valor
  # aceito em params[:sort]/usado nos links da view; o valor é a coluna
  # SQL real (já qualificada, pois "responsavel" ordena pela tabela users).
  SORTABLE_COLUMNS = {
    "title" => "demandas.title",
    "status" => "demandas.status",
    "responsavel" => "users.name",
    "created_at" => "demandas.created_at"
  }.freeze

  def index
    scope = Demanda.accessible_by(current_ability).includes(:user).references(:user)

    @q = params[:q]
    @status_filter = params[:status]
    @sort = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "created_at"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    scope = filter_demandas(scope)
      .order(Arel.sql("#{SORTABLE_COLUMNS.fetch(@sort)} #{@direction}, demandas.id #{@direction}"))

    @demandas = paginate(scope)
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
