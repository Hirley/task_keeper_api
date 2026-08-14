module ApplicationHelper
  # Cabeçalho de coluna clicável para ordenar uma listagem (Demandas,
  # Acessos...). Preserva os demais filtros/parâmetros de busca já
  # aplicados na URL atual (via request.query_parameters) e reinicia a
  # paginação para a primeira página ao trocar a ordenação.
  #
  # +default_column+: qual coluna já vem ordenada quando não há
  # params[:sort] na URL (ex.: "created_at" em Demandas, "name" em
  # Acessos) — usada só pra marcar a coluna certa como ativa nesse caso.
  # +default_direction+: direção usada quando a coluna está ativa mas não
  # há params[:direction] na URL — precisa bater com o default de cada
  # controller (ver DemandasController/UsersController #index), senão o
  # ícone mostrado (▲/▼) fica invertido em relação à ordenação real.
  def sort_header(column, label, default_column:, default_direction: "desc")
    is_default = params[:sort].blank? && column == default_column
    active = params[:sort] == column || is_default

    current_direction = if !active
      nil
    elsif params[:direction] == "asc" || params[:direction] == "desc"
      params[:direction]
    else
      default_direction
    end

    next_direction = current_direction == "asc" ? "desc" : "asc"

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
