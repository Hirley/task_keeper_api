# frozen_string_literal: true

# Controller web (HAML) para a tela de demandas. Todos os papéis podem
# criar demandas; apenas líder e admin podem editar ou excluir uma demanda
# já existente (ver app/models/ability.rb). As ações de editar/excluir só
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
    'title' => 'title',
    'data' => 'data',
    'status' => 'status',
    'responsavel' => 'user_name',
    'created_at' => 'created_at'
  }.freeze

  # Valores aceitos por "prazo" — mesmos três baldes do painel inicial
  # (ver DashboardController#index e #aplicar_filtro_de_prazo abaixo).
  PRAZOS = %w[atrasada hoje breve].freeze

  # "prazo" e "responsavel_id" são os parâmetros usados pelo drilldown do
  # painel inicial (ver app/views/dashboard/index.html.haml) — clicar num
  # total ali (Atrasadas, Vencem hoje, carga por responsável...) traz pra
  # essa mesma listagem, já filtrada. Não têm controle próprio no
  # formulário de busca (diferente de "q"/"status"): só chegam por link.
  def index
    @q = params[:q]
    @status_filter_keys = normalized_status_filter_keys
    @status_filter = @status_filter_keys.map { |status| Demanda.statuses[status] }
    @prazo_filter = normalized_prazo_filter
    @responsavel_filtrado = buscar_responsavel_filtrado
    @sort = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : 'created_at'
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'

    @demandas = paginate(demandas_filtradas)
    @title_suggestions = Demanda.distinct.order(:title).limit(50).pluck(:title)
  end

  def new
    authorize! :create, Demanda
    @demanda = Demanda.new
  end

  def edit
    authorize! :update, @demanda
  end

  def create
    authorize! :create, Demanda
    @demanda = current_user.demandas.new(demanda_params)

    if @demanda.save
      redirect_to demandas_path, notice: 'Demanda criada com sucesso.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! :update, @demanda

    if @demanda.update(demanda_params)
      redirect_to demandas_path, notice: 'Demanda atualizada com sucesso.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! :destroy, @demanda
    @demanda.destroy
    redirect_to demandas_path, notice: 'Demanda excluída com sucesso.'
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
  # dos checkboxes da tela) — Array() normaliza os dois formatos.
  #
  # Devolve as chaves do enum (strings, ex.: "concluida") — @status_filter
  # (acima, em #index) traduz pro valor inteiro que o Ransack precisa; as
  # chaves em si são o que a view usa pra marcar quais checkboxes ficam
  # pré-selecionados.
  def normalized_status_filter_keys
    Array(params[:status]).select { |status| Demanda.statuses.key?(status) }
  end

  # Divide o campo de busca por título em vários termos (separados por
  # vírgula) — cada um vira uma condição "contém" combinada com OR (ver
  # title_cont_any em #index). Um único termo sem vírgula (o caso mais
  # comum) se comporta exatamente como antes.
  def title_terms
    @q.to_s.split(',').map(&:strip).compact_blank
  end

  def normalized_prazo_filter
    params[:prazo] if PRAZOS.include?(params[:prazo])
  end

  def buscar_responsavel_filtrado
    return if params[:responsavel_id].blank?

    User.find_by(id: params[:responsavel_id])
  end

  # Extraído de #index só pra não estourar o limite do Metrics/AbcSize
  # (ver .rubocop.yml) — monta o escopo final (ability + drilldown +
  # busca/status via Ransack) e devolve o resultado já pronto pra paginar.
  #
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
  def demandas_filtradas
    scope = Demanda.accessible_by(current_ability).includes(:user)
    scope = aplicar_filtro_de_prazo(scope)
    scope = aplicar_filtro_de_responsavel(scope)

    ransack_query = scope.ransack(title_cont_any: title_terms.presence, status_in: @status_filter.presence)
    ransack_query.sorts = ["#{SORTABLE_COLUMNS.fetch(@sort)} #{@direction}", "id #{@direction}"]
    ransack_query.result
  end

  # Mesmo critério usado no painel inicial pra "Atrasadas"/"Vencem
  # hoje"/"Vencem em breve" (ver DashboardController#index) — replicado
  # aqui pra a listagem bater com o número que o usuário clicou.
  def aplicar_filtro_de_prazo(scope)
    return scope if @prazo_filter.blank?

    hoje = Date.current
    abertas = scope.where.not(status: :concluida)

    case @prazo_filter
    when 'atrasada' then abertas.where(data: ...hoje)
    when 'hoje' then abertas.where(data: hoje)
    when 'breve' then abertas.where(data: (hoje + 1)..(hoje + DashboardController::PRAZO_PROXIMO_DIAS))
    end
  end

  def aplicar_filtro_de_responsavel(scope)
    return scope if params[:responsavel_id].blank?

    scope.where(user_id: params[:responsavel_id])
  end
end
