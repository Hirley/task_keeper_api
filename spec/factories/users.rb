# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "usuario#{n}@task-keeper.local" }
    name { 'Usuário Teste' }
    password { 'senhaSegura123' }
    password_confirmation { 'senhaSegura123' }
    role { :executor }
    # Por padrão o usuário de teste já passou pelo primeiro acesso (já
    # definiu a própria senha) — é o que a maioria dos specs precisa pra
    # testar as telas normais sem cair no redirecionamento de
    # ApplicationController#exigir_troca_de_senha!. Quem precisa do estado
    # "senha provisória, ainda não trocada" usa a trait :primeiro_acesso
    # abaixo (ver spec/requests/definir_senha_spec.rb).
    must_change_password { false }

    # A criação de um usuário de teste acontece fora de qualquer
    # requisição, então declara isso (ver User#ator_dispensado) — sem a
    # marca, todo `create(:user)` da suíte falharia na validação de papel.
    #
    # O after(:create) apaga a marca em seguida, e isso é o ponto: um spec
    # que mude o papel DEPOIS está exercitando a regra, e precisa informar
    # o ator como qualquer requisição informaria. Sem essa limpeza, os
    # specs de spec/models/user_spec.rb passariam por vacuidade — todos
    # eles partem de um usuário criado por aqui.
    ator_dispensado { true }

    after(:create) do |usuario|
      usuario.ator_dispensado = false
    end

    trait :lider do
      role { :lider }
    end

    trait :executor do
      role { :executor }
    end

    trait :admin do
      role { :admin }
    end

    # Usuário recém-cadastrado pelo líder/admin com a senha provisória —
    # esse é o estado padrão de qualquer usuário novo no banco de verdade
    # (ver a coluna must_change_password, default true na migration); a
    # trait só existe porque o factory acima inverte esse default pra
    # conveniência da maioria dos outros specs.
    trait :primeiro_acesso do
      must_change_password { true }
    end
  end
end
