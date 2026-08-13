# Seeds de exemplo para ambiente de desenvolvimento.
lider = User.find_or_create_by!(email: "lider@task-keeper.local") do |u|
  u.name = "Líder Exemplo"
  u.password = "senha123456"
  u.password_confirmation = "senha123456"
  u.role = :lider
end

executor = User.find_or_create_by!(email: "executor@task-keeper.local") do |u|
  u.name = "Executor Exemplo"
  u.password = "senha123456"
  u.password_confirmation = "senha123456"
  u.role = :executor
end

Demanda.find_or_create_by!(title: "Preparar relatório semanal") do |d|
  d.description = "Consolidar as demandas concluídas na semana."
  d.status = :pendente
  d.user = executor
end

Demanda.find_or_create_by!(title: "Revisar acessos de usuários") do |d|
  d.description = "Conferir papéis (líder/executor) cadastrados."
  d.status = :em_andamento
  d.user = lider
end
