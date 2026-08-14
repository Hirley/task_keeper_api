module DemandasHelper
  # Sugestões usadas no autocomplete (datalist) do campo "Título" do
  # formulário de demanda — ajuda a evitar títulos duplicados/parecidos.
  def demanda_title_suggestions
    Demanda.distinct.where.not(title: [nil, ""]).order(:title).limit(50).pluck(:title)
  end

  # Cabeçalho de coluna clicável para ordenar a listagem de demandas.
  # A lógica em si é compartilhada com a tela de Acessos — ver
  # ApplicationHelper#sort_header.
  def demanda_sort_header(column, label)
    sort_header(column, label, default_column: "created_at", default_direction: "desc")
  end
end
