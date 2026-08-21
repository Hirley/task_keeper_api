# frozen_string_literal: true

module Relatorios
  # Monta os dados do relatório semanal de demandas — usado tanto pelo PDF
  # (Relatorios::SemanalPdf) quanto pela tela de pré-visualização
  # (RelatoriosController#show).
  #
  # Só o líder tem acesso a esta tela (ver RelatoriosController), então o
  # relatório sempre considera TODAS as demandas do sistema, não um
  # subconjunto por responsável — equivalente a `can :manage, :all`.
  #
  # "Semana" aqui é uma janela móvel dos últimos 7 dias corridos (hoje e
  # os 6 dias anteriores), não a semana de calendário (segunda a domingo).
  class Semanal
    Resultado = Struct.new(
      :periodo_inicio, :periodo_fim,
      :criadas, :concluidas, :status_counts, :atrasadas, :carga_por_responsavel,
      keyword_init: true
    )

    DIAS_NA_JANELA = 7

    def gerar
      periodo_inicio = Date.current - (DIAS_NA_JANELA - 1)
      periodo_fim = Date.current

      Resultado.new(
        periodo_inicio: periodo_inicio,
        periodo_fim: periodo_fim,
        criadas: criadas_no_periodo(periodo_inicio, periodo_fim),
        concluidas: concluidas_no_periodo(periodo_inicio, periodo_fim),
        status_counts: status_counts,
        atrasadas: atrasadas,
        carga_por_responsavel: carga_por_responsavel
      )
    end

    private

    def criadas_no_periodo(inicio, fim)
      Demanda.includes(:user).where(created_at: inicio.beginning_of_day..fim.end_of_day).order(:created_at)
    end

    # Aproximação: o model não tem um campo "concluida_em" dedicado, então
    # usamos updated_at nas demandas já concluídas dentro da janela — pode
    # incluir uma demanda que só teve outro campo editado depois de já
    # estar concluída (ex.: descrição corrigida), não só a que virou
    # concluída nesta semana. Documentado também no README.
    def concluidas_no_periodo(inicio, fim)
      Demanda.includes(:user).concluida
             .where(updated_at: inicio.beginning_of_day..fim.end_of_day)
             .order(:updated_at)
    end

    # Retrato atual (não é "da semana") — quantas demandas existem hoje em
    # cada status, pra dar contexto do backlog junto com o que mudou na
    # semana.
    def status_counts
      counts = Demanda.group(:status).count
      Demanda.statuses.keys.index_with { |status| counts[status] || 0 }
    end

    def atrasadas
      Demanda.where.not(status: :concluida).where(data: ...Date.current).count
    end

    def carga_por_responsavel
      Demanda.where.not(status: :concluida).joins(:user).group('users.id', 'users.name').count
             .map { |(_id, name), count| [name, count] }
             .sort_by { |(_name, count)| -count }
    end
  end
end
