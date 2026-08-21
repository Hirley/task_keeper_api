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
    @status_filter = normalized_status_filter
    @sort = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "created_at"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    # Ransack é usado só como mecanismo interno de query — o contrato
    # externo continua sendo os mesmos params simples de sempre (q, status,
    # sort, direction), não a sintaxe nativa do Ransack. "id" no fim mantém
    # o desempate estável que já existia antes.
    #
    # "status" aceita um ou mais valores (status=x ou status[]=x&status[]=y
    # — ver normalized_status_filter) — usa "_in" em vez de "_eq". "q"
    # aceita um ou mais termos separados por vírgula (ex.: "contrato,
    # sala") — usa "_cont_any" em vez de "_cont", pra continuar sendo
    # busca por substring (não por título exato), só que agora permitindo
    # combinar vários termos com OR.
    ransack_query = scope.ransack(title_cont_any: title_terms.presence, status_in: @status_filter.presence)
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

  # Mesma validação de antes: só deixa passar chaves válidas do enum, pra
# não deixar o Ransack tentar comparar com um valor arbitrário vindo da
# URL. Aceita um valor único (status=x, formato antigo, ainda usado por
# quem já tinha um link/favorito salvo) ou vários (status[]=x&status[]=y,
# do <select multiple> da tela) — Array() normaliza os dois formatos.
#
# Também traduz para o valor inteiro do enum (Demanda.statuses[status])
# antes de repassar ao Ransack: a coluna "status" é integer no banco e o
# Ransack não conhece o enum do Rails — sem essa tradução, "status_in"
# recebia a string ("concluida") e o cast pro tipo da coluna zerava o
# valor (equivalia a status 0/"pendente"), filtrando errado em silêncio.
def normalized_status_filter
  Array(params[:status])
    .select { |status| Demanda.statuses.key?(status) }
    .map { |status| Demanda.statuses[status] }
end

  # Divide o campo de busca por título em vários termos (separados por
  # vírgula) — cada um vira uma condição "contém" combinada com OR (ver
  # title_cont_any em #index). Um único termo sem vírgula (o caso mais
  # comum) se comporta exatamente como antes.
  def title_terms
    @q.to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
