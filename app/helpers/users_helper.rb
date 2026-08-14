module UsersHelper
  # Cabeçalho de coluna clicável para ordenar a listagem de Acessos. A
  # lógica em si é compartilhada com a tela de Demandas — ver
  # ApplicationHelper#sort_header. Default é "name"/"asc" pra preservar o
  # comportamento anterior (scope fixo em `.order(:name)`, sem ordenação
  # configurável) quando não há params[:sort] na URL.
  def user_sort_header(column, label)
    sort_header(column, label, default_column: "name", default_direction: "asc")
  end
end
