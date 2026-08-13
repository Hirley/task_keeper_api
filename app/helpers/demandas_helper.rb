module DemandasHelper
  # Sugestões usadas no autocomplete (datalist) do campo "Título" do
  # formulário de demanda — ajuda a evitar títulos duplicados/parecidos.
  def demanda_title_suggestions
    Demanda.distinct.where.not(title: [nil, ""]).order(:title).limit(50).pluck(:title)
  end

  # Cabeçalho de coluna clicável para ordenar a listagem de demandas.
  # Preserva os filtros de busca já aplicados (q, status) e reinicia a
  # paginação para a primeira página ao trocar a ordenação.
  def demanda_sort_header(column, label)
    default_column = column == "created_at" && params[:sort].blank?
    active = params[:sort] == column || default_column
    current_direction = active && params[:direction] == "asc" ? "asc" : (active ? "desc" : nil)
    next_direction = active && current_direction == "asc" ? "desc" : "asc"

    url = url_for(request.query_parameters.merge(
      "sort" => column, "direction" => next_direction, "page" => nil
    ))

    icon = if active
      content_tag(:span, current_direction == "asc" ? "▲" : "▼", class: "tk-sort-icon", "aria-hidden" => "true")
    end

    link_to url, class: "tk-sort-link#{' tk-sort-active' if active}" do
      safe_join([label, icon].compact, " ")
    end
  end
end
