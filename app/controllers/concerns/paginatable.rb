# Paginação simples, sem dependência de gem externa (kaminari/will_paginate).
#
# Optamos por implementar isso "na mão" porque este sandbox de
# desenvolvimento não tem acesso à rede para o rubygems.org nem uma versão
# de Ruby compatível com o Gemfile — então não dá pra rodar `bundle install`
# e validar uma gem nova aqui. A paginação abaixo usa só Active Record
# (limit/offset), então funciona com o Gemfile atual sem exigir nenhuma
# instalação adicional.
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 10

  private

  # Recebe um relation (scope) e devolve o relation já limitado à página
  # atual (params[:page]). Também guarda os metadados da paginação em
  # @pagination, para a view renderizar os links (ver
  # app/views/shared/_pagination.html.haml).
  def paginate(scope, per: DEFAULT_PER_PAGE)
    total_count = scope.count
    total_pages = [(total_count.to_f / per).ceil, 1].max

    page = params[:page].to_i
    page = 1 if page < 1
    page = total_pages if page > total_pages

    @pagination = {
      current_page: page,
      total_pages: total_pages,
      total_count: total_count,
      per_page: per
    }

    scope.limit(per).offset((page - 1) * per)
  end
end
