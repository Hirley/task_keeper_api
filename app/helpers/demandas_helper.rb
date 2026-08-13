module DemandasHelper
  # Sugestões usadas no autocomplete (datalist) do campo "Título" do
  # formulário de demanda — ajuda a evitar títulos duplicados/parecidos.
  def demanda_title_suggestions
    Demanda.distinct.where.not(title: [nil, ""]).order(:title).limit(50).pluck(:title)
  end
end
