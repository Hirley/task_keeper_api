# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "usuario#{n}@task-keeper.local" }
    name { 'Usuário Teste' }
    password { 'senha123456' }
    password_confirmation { 'senha123456' }
    role { :executor }

    trait :lider do
      role { :lider }
    end

    trait :executor do
      role { :executor }
    end
  end
end
