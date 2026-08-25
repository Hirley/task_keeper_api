# frozen_string_literal: true

# Painel inicial (home) da aplicação — visão geral das demandas para
# qualquer usuário autenticado (executor, líder ou admin). Não há ações de
# escrita aqui, só leitura, então não precisa de `authorize!`: as
# consultas já são todas escopadas por `current_ability`, igual à
# listagem de demandas (ver DemandasController#index).
class DashboardController < ApplicationController
  PRAZO_PROXIMO_DIAS = 3

  def index
    demandas = Demanda.accessible_by(current_ability).includes(:user)

    @total = demandas.count
    @status_counts = status_counts(demandas)

    @minhas_demandas = current_user.demandas
                                   .order(Arel.sql('(status = 2) ASC, data ASC'))
                                   .limit(6)

    @atividade_recente = demandas.order(created_at: :desc).limit(5)

    abertas = demandas.where.not(status: :concluida)
    hoje = Date.current
    @atrasadas = abertas.where(data: ...hoje).count
    @vencem_hoje = abertas.where(data: hoje).count
    @vencem_em_breve = abertas.where(data: (hoje + 1)..(hoje + PRAZO_PROXIMO_DIAS)).count

    @carga_por_responsavel = carga_por_responsavel(abertas)
  end

  private

  def status_counts(demandas)
    counts = demandas.group(:status).count
    Demanda.statuses.keys.index_with { |status| counts[status] || 0 }
  end

  # Quantidade de demandas ainda abertas (não concluídas) por responsável,
  # da maior carga para a menor. Mantém o id (não só o nome) porque a view
  # usa ele pra montar o link de drilldown pra listagem de demandas
  # filtrada por responsável (ver app/views/dashboard/index.html.haml e
  # DemandasController#index).
  def carga_por_responsavel(abertas)
    abertas.joins(:user).group('users.id', 'users.name').count
           .map { |(id, name), count| [id, name, count] }
           .sort_by { |(_id, _name, count)| -count }
  end
end
