# frozen_string_literal: true

# Não roda em ambiente de teste: bin/rails db:prepare (usado tanto
# localmente quanto no CI) semeia o banco automaticamente na primeira vez
# que ele é criado. Em teste isso poluiria a suíte inteira — RSpec usa
# transação por exemplo, mas estes registros são commitados ANTES da
# suíte começar, então persistem durante todos os exemplos (foi a causa
# raiz de ~11 falhas reais expostas quando o CI passou a rodar de
# verdade — ver issue #49). Só faz sentido em development/produção.
return if Rails.env.test?

# Seeds de exemplo para ambiente de desenvolvimento.
#
# O `u.ator_dispensado = true` dos três usuários abaixo declara o óbvio
# para o model: seeds rodam fora de qualquer requisição, não há ator e não
# há fronteira a defender. Sem essa declaração a criação é recusada — ver
# User#validar_atribuicao_de_papel, que trata ator ausente como recusa e
# não como dispensa.
User.find_or_create_by!(email: 'admin@task-keeper.local') do |u|
  u.name = 'Admin Exemplo'
  u.password = 'senhaSegura123'
  u.password_confirmation = 'senhaSegura123'
  u.role = :admin
  u.ator_dispensado = true
end

lider = User.find_or_create_by!(email: 'lider@task-keeper.local') do |u|
  u.name = 'Líder Exemplo'
  u.password = 'senhaSegura123'
  u.password_confirmation = 'senhaSegura123'
  u.role = :lider
  u.ator_dispensado = true
end

executor = User.find_or_create_by!(email: 'executor@task-keeper.local') do |u|
  u.name = 'Executor Exemplo'
  u.password = 'senhaSegura123'
  u.password_confirmation = 'senhaSegura123'
  u.role = :executor
  u.ator_dispensado = true
end

Demanda.find_or_create_by!(title: 'Preparar relatório semanal') do |d|
  d.description = 'Consolidar as demandas concluídas na semana.'
  d.status = :pendente
  d.user = executor
end

Demanda.find_or_create_by!(title: 'Revisar acessos de usuários') do |d|
  d.description = 'Conferir papéis (líder/executor) cadastrados.'
  d.status = :em_andamento
  d.user = lider
end
