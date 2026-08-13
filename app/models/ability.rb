# Regras de autorização (CanCanCan) — refletem as regras de negócio:
#
#   * Ambos os papéis (líder e executor) podem cadastrar novas demandas.
#   * Apenas o líder pode editar ou excluir uma demanda já existente.
#   * Apenas o líder pode cadastrar/gerenciar usuários (não há autocadastro).
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
