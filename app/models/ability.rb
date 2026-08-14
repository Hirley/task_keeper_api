# Regras de autorização (CanCanCan) — refletem as regras de negócio:
#
#   * Ambos os papéis (líder e executor) podem cadastrar novas demandas.
#   * Apenas o líder pode editar ou excluir uma demanda já existente.
#   * Apenas o líder pode cadastrar/gerenciar usuários (não há autocadastro).
#   * Apenas o líder acessa o relatório semanal (RelatoriosController,
#     autorizado via `can? :read, :relatorio` — símbolo, não um model,
#     porque não existe uma tabela/registro "Relatorio"; já coberto pelo
#     `can :manage, :all` do líder abaixo, sem precisar de uma regra à
#     parte).
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?

    if user.lider?
      can :manage, :all
    else
      can :create, Demanda
      can :read, Demanda
    end
  end
end
