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

// Barra de acessibilidade (ver app/views/layouts/application.html.haml):
// tamanho de fonte e alto contraste. Os botões chamam window.TkAccessibility
// diretamente via onclick — como o Turbo Drive substitui o <body> a cada
// navegação mas nunca recria o <html>/o contexto JS, um objeto global
// simples aqui dispensa reanexar event listeners a cada "turbo:load".
const TK_FONT_SCALE_KEY = "tk-font-scale"
const TK_CONTRAST_KEY = "tk-high-contrast"
const TK_FONT_SCALE_DEFAULT = 100
const TK_FONT_SCALE_MIN = 80
const TK_FONT_SCALE_MAX = 150
const TK_FONT_SCALE_STEP = 10

function readStoredFontScale() {
  const stored = parseInt(localStorage.getItem(TK_FONT_SCALE_KEY), 10)
  return Number.isFinite(stored) ? stored : TK_FONT_SCALE_DEFAULT
}

function applyFontScale(scale) {
  const clamped = Math.min(TK_FONT_SCALE_MAX, Math.max(TK_FONT_SCALE_MIN, scale))
  document.documentElement.style.fontSize = clamped + "%"
  localStorage.setItem(TK_FONT_SCALE_KEY, String(clamped))
}

function isHighContrastStored() {
  return localStorage.getItem(TK_CONTRAST_KEY) === "true"
}

function applyContrast(enabled) {
  document.documentElement.classList.toggle("tk-high-contrast", enabled)
  localStorage.setItem(TK_CONTRAST_KEY, String(enabled))

  const toggleButton = document.getElementById("tk-contrast-toggle")
  if (toggleButton) {
    toggleButton.setAttribute("aria-pressed", String(enabled))
    toggleButton.setAttribute("aria-label", enabled ? "Desativar alto contraste" : "Ativar alto contraste")
  }
}

function applyStoredAccessibilityPreferences() {
  applyFontScale(readStoredFontScale())
  applyContrast(isHighContrastStored())
}

window.TkAccessibility = {
  increaseFont() { applyFontScale(readStoredFontScale() + TK_FONT_SCALE_STEP) },
  decreaseFont() { applyFontScale(readStoredFontScale() - TK_FONT_SCALE_STEP) },
  resetFont() { applyFontScale(TK_FONT_SCALE_DEFAULT) },
  toggleContrast() { applyContrast(!isHighContrastStored()) }
}

// Reaplica a cada navegação Turbo: o tamanho de fonte já fica no <html> e
// sobrevive à troca de <body>, mas o botão de contraste é recriado a cada
// página e precisa que seu aria-pressed/aria-label reflitam o estado atual.
document.addEventListener("turbo:load", applyStoredAccessibilityPreferences)
