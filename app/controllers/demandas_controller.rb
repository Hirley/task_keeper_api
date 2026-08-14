# Controller web (HAML) para a tela de demandas. Ambos os papéis podem
# criar demandas; apenas o líder pode editar ou excluir uma demanda já
# existente (ver app/models/ability.rb). As ações de editar/excluir só
# aparecem na tela para quem tem permissão (ver app/views/demandas/index.html.haml).
class DemandasController < ApplicationController
  before_action :set_demanda, only: %i[edit update destroy]

  # Colunas que podem ser usadas para ordenar a listagem (whitelist — nunca
  # interpolar params[:sort] direto numa query). A chave é o valor aceito em
  # params[:sort]/usado nos links da view; o valor é o nome do atributo no
  # Ransack (ver Demanda.ransackable_attributes/ransackable_associations) —
  # "user_name" é a convenção do Ransack para "atributo name da associação
  # user" (antes disso usávamos a coluna SQL "users.name" diretamente).
  SORTABLE_COLUMNS = {
    "title" => "title",
    "data" => "data",
    "status" => "status",
    "responsavel" => "user_name",
    "created_at" => "created_at"
  }.freeze

  def index
    scope = Demanda.accessible_by(current_ability).includes(:user)

    @q = params[:q]
    @status_filter = params[:status]
    @sort = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "created_at"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    # Ransack é usado só como mecanismo interno de query — o contrato
    # externo continua sendo os mesmos params simples de sempre (q, status,
    # sort, direction), não a sintaxe nativa do Ransack. "id" no fim mantém
    # o desempate estável que já existia antes.
    ransack_query = scope.ransack(title_cont: @q.presence, status_eq: normalized_status_filter)
    ransack_query.sorts = ["#{SORTABLE_COLUMNS.fetch(@sort)} #{@direction}", "id #{@direction}"]

    @demandas = paginate(ransack_query.result)
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
    params.require(:demanda).permit(:title, :description, :status, :data)
  end

  # Mesma validação de antes: só aplica o filtro de status se for uma chave
  # válida do enum, para não deixar o Ransack tentar comparar com um valor
  # arbitrário vindo da URL.
  def normalized_status_filter
    return nil unless params[:status].present? && Demanda.statuses.key?(params[:status])

    params[:status]
  end
end
