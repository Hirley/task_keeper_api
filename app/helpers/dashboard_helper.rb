# frozen_string_literal: true

module DashboardHelper
  # Badge de urgência de prazo para uma demanda ainda aberta — "atrasada"
  # (dias já vencidos) ou "vence em breve" (hoje, amanhã, ou dentro da
  # janela de alerta do painel). Não retorna nada para demandas
  # concluídas nem para prazos confortáveis (fora da janela de alerta).
  #
  # É um canal deliberadamente separado do badge de status
  # (tk-badge-status-*): um mostra em que fase a demanda está, o outro se
  # ela está no prazo — misturar os dois na mesma cor confundiria mais do
  # que ajudaria.
  def prazo_badge(demanda)
    return if demanda.concluida?

    dias = (demanda.data - Date.current).to_i

    if dias.negative?
      texto = dias.abs == 1 ? 'Atrasada há 1 dia' : "Atrasada há #{dias.abs} dias"
      content_tag(:span, "⚠ #{texto}", class: 'badge-urg badge-urg-critical')
    elsif dias.zero?
      content_tag(:span, 'Vence hoje', class: 'badge-urg badge-urg-warning')
    elsif dias == 1
      content_tag(:span, 'Vence amanhã', class: 'badge-urg badge-urg-warning')
    elsif dias <= DashboardController::PRAZO_PROXIMO_DIAS
      content_tag(:span, "Vence em #{dias} dias", class: 'badge-urg badge-urg-warning')
    end
  end
end
