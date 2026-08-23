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

// Tooltips do Bootstrap (ex.: o ⓘ de ajuda do campo "Chat ID do Telegram"
// em app/views/users/_form.html.haml) não se inicializam sozinhos — é
// preciso instanciar cada um. getOrCreateInstance evita duplicar a
// instância se essa função rodar mais de uma vez para o mesmo elemento.
function initializeTooltips() {
  if (typeof bootstrap === "undefined" || !bootstrap.Tooltip) return

  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((element) => {
    bootstrap.Tooltip.getOrCreateInstance(element)
  })
}

document.addEventListener("turbo:load", initializeTooltips)

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

// Busca global (navbar — ver app/views/layouts/application.html.haml e
// SearchController). Dropdown de sugestões em tempo real (busca "/busca.json"
// conforme digita) + busca por voz via Web Speech API, quando suportada.
const TK_SEARCH_DEBOUNCE_MS = 250
const TK_SEARCH_MIN_CHARS = 2

function tkEscapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}

// Fecha o dropdown ao clicar fora — registrado uma única vez em
// document (não a cada "turbo:load", que troca só o <body>: reattachar
// aqui empilharia um listener novo a cada navegação, todos apontando pra
// elementos já substituídos). Busca os elementos atuais a cada clique em
// vez de fechar sobre uma referência antiga.
document.addEventListener("click", (event) => {
  const dropdown = document.getElementById("tk-search-results")
  const input = document.getElementById("tk-search-input")
  if (!dropdown || dropdown.hidden) return
  if (event.target === input || dropdown.contains(event.target)) return

  dropdown.hidden = true
  dropdown.innerHTML = ""
  input?.setAttribute("aria-expanded", "false")
  input?.removeAttribute("aria-activedescendant")
})

function initSearchDropdown() {
  const input = document.getElementById("tk-search-input")
  const dropdown = document.getElementById("tk-search-results")
  if (!input || !dropdown) return

  let debounceTimer = null
  let activeIndex = -1

  function closeDropdown() {
    dropdown.hidden = true
    dropdown.innerHTML = ""
    input.setAttribute("aria-expanded", "false")
    input.removeAttribute("aria-activedescendant")
    activeIndex = -1
  }

  function highlightOption(options) {
    options.forEach((option, index) => {
      option.classList.toggle("tk-search-result-active", index === activeIndex)
    })
    if (activeIndex >= 0) {
      input.setAttribute("aria-activedescendant", options[activeIndex].id)
      options[activeIndex].scrollIntoView({ block: "nearest" })
    } else {
      input.removeAttribute("aria-activedescendant")
    }
  }

  function renderResults(data) {
    const items = [
      ...data.demandas.map((result) => ({ ...result, kind: "Demanda" })),
      ...data.users.map((result) => ({ ...result, kind: "Acesso" }))
    ]

    activeIndex = -1

    if (items.length === 0) {
      dropdown.innerHTML = '<p class="tk-search-empty">Nada encontrado.</p>'
    } else {
      dropdown.innerHTML = items.map((item, index) => `
        <a href="${tkEscapeHtml(item.url)}" class="tk-search-result" role="option" id="tk-search-option-${index}">
          <span class="tk-search-result-kind">${tkEscapeHtml(item.kind)}</span>
          <span class="tk-search-result-title">${tkEscapeHtml(item.title)}</span>
          ${item.subtitle ? `<span class="tk-search-result-subtitle">${tkEscapeHtml(item.subtitle)}</span>` : ""}
        </a>
      `).join("")
    }

    dropdown.hidden = false
    input.setAttribute("aria-expanded", "true")
  }

  function fetchResults(query) {
    fetch(`/busca.json?q=${encodeURIComponent(query)}`, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then(renderResults)
      .catch(() => closeDropdown())
  }

  input.addEventListener("input", () => {
    clearTimeout(debounceTimer)
    const query = input.value.trim()

    if (query.length < TK_SEARCH_MIN_CHARS) {
      closeDropdown()
      return
    }

    debounceTimer = setTimeout(() => fetchResults(query), TK_SEARCH_DEBOUNCE_MS)
  })

  input.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeDropdown()
      return
    }

    const options = Array.from(dropdown.querySelectorAll(".tk-search-result"))
    if (dropdown.hidden || options.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      activeIndex = Math.min(activeIndex + 1, options.length - 1)
      highlightOption(options)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      activeIndex = Math.max(activeIndex - 1, 0)
      highlightOption(options)
    } else if (event.key === "Enter" && activeIndex >= 0) {
      event.preventDefault()
      options[activeIndex].click()
    }
  })
}

// Botão de microfone só aparece se o navegador suportar a Web Speech API
// (Chrome/Edge; Firefox e Safari não suportam bem) — progressive
// enhancement, sem quebrar em quem não tem suporte.
function initVoiceSearch() {
  const micButton = document.getElementById("tk-search-mic")
  const input = document.getElementById("tk-search-input")
  if (!micButton || !input) return

  const SpeechRecognitionCtor = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SpeechRecognitionCtor) return

  micButton.hidden = false
  let listening = false

  micButton.addEventListener("click", () => {
    if (listening) return

    const recognition = new SpeechRecognitionCtor()
    recognition.lang = "pt-BR"
    recognition.interimResults = false
    recognition.maxAlternatives = 1

    listening = true
    micButton.classList.add("tk-search-mic-listening")
    micButton.setAttribute("aria-label", "Ouvindo…")

    const stopListening = () => {
      listening = false
      micButton.classList.remove("tk-search-mic-listening")
      micButton.setAttribute("aria-label", "Buscar por voz")
    }

    recognition.addEventListener("result", (event) => {
      input.value = event.results[0][0].transcript
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.focus()
    })

    recognition.addEventListener("end", stopListening)
    recognition.addEventListener("error", stopListening)

    recognition.start()
  })
}

document.addEventListener("turbo:load", () => {
  initSearchDropdown()
  initVoiceSearch()
})
