# frozen_string_literal: true

module ApplicationHelper
  # Chaves que o url_for interpreta como opção de roteamento (pra onde o
  # link aponta) em vez de query string. Se uma delas chegar pela URL e
  # for repassada crua pro url_for, quem monta o link passa a controlar o
  # destino: um ?host=evil.com na barra de endereços basta pra que TODO
  # link de paginação e de ordenação da página aponte pro host do
  # atacante — open redirect com cara de link legítimo, porque a página
  # que o usuário está vendo é a nossa mesmo. Por isso #query_url
  # descarta essas chaves antes de remontar a URL.
  URL_OPTION_KEYS = %w[
    host protocol port subdomain domain tld_length
    controller action format script_name relative_url_root
    only_path trailing_slash anchor params user password
  ].freeze

  # Remonta a URL da tela atual preservando os filtros já aplicados na
  # query string (busca, status, ordenação...) e sobrescrevendo só o que
  # +overrides+ pedir. Chave com valor nil sai da URL — é assim que
  # #sort_header volta pra primeira página ao trocar a coluna.
  #
  # Usado pela paginação (app/views/shared/_pagination.html.haml) e pelos
  # links de ordenação: os dois precisam manter os filtros do usuário ao
  # navegar, e é justamente esse "repassa a query string adiante" que
  # exige a limpeza acima.
  #
  # only_path: true é redundante depois do #except (sem :host o url_for
  # já devolve caminho relativo), mas fica explícito de propósito: é a
  # garantia que continua valendo mesmo se a lista de chaves acima ficar
  # desatualizada em alguma versão futura do Rails.
  def query_url(overrides = {})
    preservados = request.query_parameters.except(*URL_OPTION_KEYS)

    url_for(preservados.merge(overrides).compact.merge(only_path: true))
  end

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
  def sort_header(column, label, default_column:, default_direction: 'desc')
    is_default = params[:sort].blank? && column == default_column
    active = params[:sort] == column || is_default

    current_direction = if !active
                          nil
                        elsif %w[asc desc].include?(params[:direction])
                          params[:direction]
                        else
                          default_direction
                        end

    next_direction = current_direction == 'asc' ? 'desc' : 'asc'

    url = query_url('sort' => column, 'direction' => next_direction, 'page' => nil)

    icon = if active
             content_tag(:span, current_direction == 'asc' ? '▲' : '▼', class: 'tk-sort-icon', 'aria-hidden' => 'true')
           end

    link_to url, class: "tk-sort-link#{' tk-sort-active' if active}" do
      safe_join([label, icon].compact, ' ')
    end
  end
end
