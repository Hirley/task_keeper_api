# frozen_string_literal: true

# Monta a lista de páginas a exibir na paginação, com "..." (:gap) quando
# há muitas páginas — evita renderizar uma lista gigante de números.
#
# Exemplo com página atual 8 de 20: [1, :gap, 6, 7, 8, 9, 10, :gap, 20]
module PaginationHelper
  def pagination_window(current_page, total_pages, radius: 2)
    return (1..total_pages).to_a if total_pages <= (radius * 2) + 5

    pages = ([1, 2] + ((current_page - radius)..(current_page + radius)).to_a + [total_pages - 1, total_pages])
            .grep(1..total_pages)
            .uniq
            .sort

    result = []
    pages.each_with_index do |page, index|
      result << :gap if index.positive? && page - pages[index - 1] > 1
      result << page
    end
    result
  end
end
