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

    contagem_por_papel if current_user.lider_ou_admin?
  end

  private

  # Card "Equipe", visível só pra líder/admin (ver
  # app/views/dashboard/index.html.haml) — extraído do #index só pra não
  # estourar o limite do Metrics/AbcSize (ver .rubocop.yml).
  def contagem_por_papel
    @total_lideres = User.lider.count
    @total_executores = User.executor.count
    @total_admins = User.admin.count
  end

  def status_counts(demandas)
    counts = demandas.group(:status).count
    Demanda.statuses.keys.index_with { |status| counts[status] || 0 }
  end

  # Quantidade de demandas ainda abertas (não concluídas) por responsável,
  # da maior carga para a menor.
  def carga_por_responsavel(abertas)
    abertas.joins(:user).group('users.id', 'users.name').count
           .map { |(_id, name), count| [name, count] }
           .sort_by { |(_name, count)| -count }
  end
end
