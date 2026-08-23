# frozen_string_literal: true

# Tela de cadastro de webhooks de saída (web) — só o admin tem acesso,
# nem líder chega aqui (ver app/models/ability.rb: líder tem
# `can :manage, :all`, mas com `cannot :manage, WebhookSubscription`
# específico pra essa exceção).
#
# Não é escopado por usuário: qualquer admin vê/edita/remove qualquer
# webhook cadastrado, mesmo padrão já usado em Acessos e Demandas (quem
# gerencia, gerencia tudo, não só o que criou).
class WebhookSubscriptionsController < ApplicationController
  before_action :authorize_manage!
  before_action :set_webhook_subscription, only: %i[edit update destroy]

  def index
    @webhook_subscriptions = WebhookSubscription.order(:created_at)
  end

  def new
    @webhook_subscription = WebhookSubscription.new(events: [])
  end

  def edit
    # Nada além do before_action :set_webhook_subscription — a view só
    # renderiza o form parcial reaproveitado de #new.
  end

  def create
    @webhook_subscription = current_user.webhook_subscriptions.new(webhook_subscription_params)

    if @webhook_subscription.save
      redirect_to webhook_subscriptions_path, notice: 'Webhook cadastrado com sucesso.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @webhook_subscription.update(webhook_subscription_params)
      redirect_to webhook_subscriptions_path, notice: 'Webhook atualizado com sucesso.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @webhook_subscription.destroy
    redirect_to webhook_subscriptions_path, notice: 'Webhook removido com sucesso.'
  end

  private

  def authorize_manage!
    authorize! :manage, WebhookSubscription
  end

  def set_webhook_subscription
    @webhook_subscription = WebhookSubscription.find(params[:id])
  end

  def webhook_subscription_params
    params.require(:webhook_subscription).permit(:url, :active, events: [])
  end
end
