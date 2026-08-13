// Entry point para importmap-rails.
//
// Carrega o Turbo para que os data-turbo-confirm (usados, por exemplo, no
// botão "Excluir" de app/views/demandas/index.html.haml) mostrem o alerta
// de confirmação antes de enviar o form de exclusão.
import "@hotwired/turbo-rails"

// Fecha automaticamente os alertas de flash (ver app/views/layouts/application.html.haml)
// depois de um tempo, sem precisar esperar o usuário clicar no "×"
// (data-bs-dismiss="alert", já suportado pelo Bootstrap). O usuário
// continua podendo fechar manualmente a qualquer momento antes disso.
const ALERT_AUTO_DISMISS_MS = 40000

function scheduleAlertAutoDismiss() {
  document.querySelectorAll(".tk-alert").forEach((alertElement) => {
    setTimeout(() => {
      if (!document.body.contains(alertElement)) return

      if (typeof bootstrap !== "undefined" && bootstrap.Alert) {
        bootstrap.Alert.getOrCreateInstance(alertElement).close()
      } else {
        alertElement.remove()
      }
    }, ALERT_AUTO_DISMISS_MS)
  })
}

// "turbo:load" dispara tanto no carregamento inicial da página quanto
// depois de cada navegação via Turbo Drive (que não recarrega a página
// inteira, então um simples DOMContentLoaded não seria suficiente).
document.addEventListener("turbo:load", scheduleAlertAutoDismiss)
