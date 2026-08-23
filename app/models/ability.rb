# frozen_string_literal: true

# Regras de autorização (CanCanCan) — refletem as regras de negócio:
#
#   * Todos os papéis (executor, líder, admin) podem cadastrar novas demandas.
#   * Líder e admin podem editar ou excluir uma demanda já existente.
#   * Líder e admin podem cadastrar/gerenciar usuários e alterar permissões
#     (não há autocadastro) — mas só admin edita o telegram_chat_id de um
#     usuário (restrição de atributo, não dá pra expressar via CanCan; ver
#     UsersController#user_params/#permission_params e
#     app/views/users/_form.html.haml).
#   * Líder e admin acessam o relatório semanal (RelatoriosController,
#     autorizado via `can? :read, :relatorio` — símbolo, não um model,
#     porque não existe uma tabela/registro "Relatorio"; já coberto pelo
#     `can :manage, :all` abaixo, sem precisar de uma regra à parte).
#   * Só admin cadastra/gerencia webhooks de saída (WebhookSubscription —
#     ver app/controllers/webhook_subscriptions_controller.rb): líder tem
#     `can :manage, :all` como admin, mas com um `cannot` específico pra
#     essa exceção.
class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    if user.admin?
      can :manage, :all
    elsif user.lider?
      can :manage, :all
      cannot :manage, WebhookSubscription
    else
      can :create, Demanda
      can :read, Demanda
    end
  end
end
