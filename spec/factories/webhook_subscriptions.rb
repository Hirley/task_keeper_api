# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_subscription do
    # IP literal em vez de hostname: Resolv.getaddresses reconhece um IP
    # literal sem fazer nenhuma resolução de DNS de verdade (ver
    # app/models/webhook_subscription.rb) — mantém a validação
    # determinística nos testes, sem depender de rede/DNS externo.
    url { 'http://8.8.8.8/hook' }
    events { %w[demanda_criada] }
    active { true }
    association :user

    trait :inativo do
      active { false }
    end
  end
end
