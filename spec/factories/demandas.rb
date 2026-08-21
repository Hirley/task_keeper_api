# frozen_string_literal: true

FactoryBot.define do
  factory :demanda do
    title { 'Demanda de teste' }
    description { 'Descrição da demanda de teste' }
    status { :pendente }
    association :user

    trait :em_andamento do
      status { :em_andamento }
    end

    trait :concluida do
      status { :concluida }
    end
  end
end
