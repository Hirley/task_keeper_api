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

// Guia interativo (tour) do dashboard — sem dependência externa (mesmo
// espírito do TkAccessibility acima). Passos fixos aqui; os que apontam
// pra elementos que não existem na tela do usuário atual (ex.: "Acessos"
// pra quem não é líder/admin — ver app/views/layouts/application.html.haml)
// são descartados no #start, então não precisa montar essa lista no
// servidor. Roda só na página inicial (onde os alvos existem de fato —
// ver data-tour em app/views/dashboard/index.html.haml); disparado pelo
// #tk-tour-autostart (primeiro acesso ao dashboard) ou pelo botão 🧭 da
// navbar (data-tour="tour-trigger").
const TK_TOUR_STEPS = [
  {
    title: "Bem-vindo(a) ao Task Keeper!",
    body: "Um tour rápido pelas principais telas. Você pode sair a qualquer momento clicando em “Pular” ou na tecla Esc."
  },
  {
    title: "Resumo das demandas",
    body: "Total, pendentes, em andamento e concluídas — clique em qualquer cartão pra ver a lista já filtrada.",
    target: '[data-tour="stats"]'
  },
  {
    title: "Minhas demandas",
    body: "As demandas atribuídas a você, ordenadas pelas mais urgentes primeiro.",
    target: '[data-tour="minhas-demandas"]'
  },
  {
    title: "Menu Demandas",
    body: "Veja, cadastre e acompanhe todas as demandas da equipe.",
    target: '[data-tour="nav-demandas"]'
  },
  {
    title: "Acessos",
    body: "Cadastre novos usuários e defina permissões (líder e admin).",
    target: '[data-tour="nav-acessos"]'
  },
  {
    title: "Busca rápida",
    body: "Digite pra encontrar demandas ou pessoas na hora — ou use o microfone 🎤, se o navegador suportar.",
    target: '[data-tour="nav-busca"]'
  },
  {
    title: "Acessibilidade",
    body: "Tamanho de fonte, alto contraste e tradução em Libras ficam aqui em cima.",
    target: ".tk-a11y-bar"
  },
  {
    title: "Reveja quando quiser",
    body: "Esse ícone fica sempre disponível pra rever o tour a qualquer momento.",
    target: '[data-tour="tour-trigger"]'
  }
]

const TK_TOUR_SPOTLIGHT_PADDING = 8

function tkTourCsrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content
}

// Marca no servidor que o usuário já viu (ou pulou) o tour, pra não
// disparar sozinho de novo no próximo login — ver TourController. Só
// controla o disparo automático: o botão 🧭 continua funcionando mesmo
// depois disso.
function tkTourMarkCompleted() {
  const token = tkTourCsrfToken()
  if (!token) return

  fetch("/tour/concluir", {
    method: "PATCH",
    headers: { "X-CSRF-Token": token, Accept: "application/json" }
  }).catch(() => {})
}

function tkTourBuildOverlay() {
  const overlay = document.createElement("div")
  overlay.className = "tk-tour-overlay"

  const spotlight = document.createElement("div")
  spotlight.className = "tk-tour-spotlight"
  overlay.appendChild(spotlight)

  const tooltip = document.createElement("div")
  tooltip.className = "tk-tour-tooltip"
  tooltip.setAttribute("role", "dialog")
  tooltip.setAttribute("aria-modal", "true")
  tooltip.tabIndex = -1
  overlay.appendChild(tooltip)

  document.body.appendChild(overlay)
  return { overlay, spotlight, tooltip }
}

window.TkGuideTour = {
  _steps: [],
  _index: 0,
  _els: null,
  _reposition: null,

  start() {
    if (this._els) this._teardown()

    this._steps = TK_TOUR_STEPS.filter((step) => !step.target || document.querySelector(step.target))
    if (this._steps.length === 0) return

    this._index = 0
    this._els = tkTourBuildOverlay()

    this._onKeydown = (event) => {
      if (event.key === "Escape") this.finish()
      else if (event.key === "ArrowRight") this.next()
      else if (event.key === "ArrowLeft") this.prev()
    }
    document.addEventListener("keydown", this._onKeydown)

    // Só reposiciona (sem reconstruir o conteúdo nem roubar foco de
    // novo) — chamar _render aqui criaria um loop de scrollIntoView
    // brigando com o usuário a cada evento de "scroll".
    this._reposition = () => this._updatePosition(this._currentTarget())
    window.addEventListener("resize", this._reposition)
    window.addEventListener("scroll", this._reposition, true)

    this._render()
  },

  next() {
    if (this._index >= this._steps.length - 1) {
      this.finish()
      return
    }
    this._index += 1
    this._render()
  },

  prev() {
    if (this._index <= 0) return
    this._index -= 1
    this._render()
  },

  // "Pular" e "Concluir" levam ao mesmo lugar: marcar como visto e fechar.
  // Não faz sentido voltar a incomodar quem já pulou uma vez.
  finish() {
    tkTourMarkCompleted()
    this._teardown()
  },

  _teardown() {
    if (this._onKeydown) document.removeEventListener("keydown", this._onKeydown)
    if (this._reposition) {
      window.removeEventListener("resize", this._reposition)
      window.removeEventListener("scroll", this._reposition, true)
    }
    this._els?.overlay.remove()
    this._els = null
  },

  _currentTarget() {
    const step = this._steps[this._index]
    return step.target ? document.querySelector(step.target) : null
  },

  // Conteúdo e uma posição inicial são renderizados na hora, sem esperar
  // nada — importante porque requestAnimationFrame não dispara enquanto o
  // documento está oculto (aba em segundo plano, janela minimizada etc.),
  // e antes disso o tour dependia dele até pra mostrar o texto: se o rAF
  // não disparasse logo (ou nunca, com a aba oculta), o overlay escurecia
  // a tela e o tooltip ficava vazio pra sempre. Só o reposicionamento
  // fino (depois que o scroll suave termina) fica no rAF — se ele
  // atrasar, o tour continua visível e usável, só com a posição
  // ligeiramente desatualizada até o frame seguinte.
  _render() {
    const step = this._steps[this._index]
    const target = this._currentTarget()

    if (step.target && !target) {
      // Elemento sumiu da tela entre um passo e outro (ex.: resize
      // colapsou a navbar) — pula pro próximo em vez de travar num
      // spotlight apontando pro nada.
      this.next()
      return
    }

    this._renderStep(step, target)
    target?.scrollIntoView({ block: "center", behavior: "smooth" })
    requestAnimationFrame(() => requestAnimationFrame(() => this._updatePosition(target)))
  },

  _renderStep(step, target) {
    if (!this._els) return
    const { tooltip } = this._els

    tooltip.innerHTML = this._tooltipHtml(step)
    tooltip.querySelector('[data-tour-action="prev"]')?.addEventListener("click", () => this.prev())
    tooltip.querySelector('[data-tour-action="next"]').addEventListener("click", () => this.next())
    tooltip.querySelector('[data-tour-action="skip"]').addEventListener("click", () => this.finish())

    this._updatePosition(target)
    tooltip.focus()
  },

  // Só recalcula posição/tamanho (spotlight + tooltip) a partir do alvo
  // atual — sem tocar no conteúdo nem no foco. Chamado tanto depois de
  // trocar de passo quanto em "resize"/"scroll" (ver _reposition).
  _updatePosition(target) {
    if (!this._els) return
    const { spotlight, tooltip } = this._els

    spotlight.classList.toggle("tk-tour-spotlight-full", !target)

    if (target) {
      const rect = target.getBoundingClientRect()
      spotlight.style.top = `${rect.top - TK_TOUR_SPOTLIGHT_PADDING}px`
      spotlight.style.left = `${rect.left - TK_TOUR_SPOTLIGHT_PADDING}px`
      spotlight.style.width = `${rect.width + TK_TOUR_SPOTLIGHT_PADDING * 2}px`
      spotlight.style.height = `${rect.height + TK_TOUR_SPOTLIGHT_PADDING * 2}px`
    }

    this._positionTooltip(tooltip, target)
  },

  _tooltipHtml(step) {
    const isLast = this._index === this._steps.length - 1
    return `
      <p class="tk-tour-progress">Passo ${this._index + 1} de ${this._steps.length}</p>
      <h2 class="tk-tour-title">${step.title}</h2>
      <p class="tk-tour-body">${step.body}</p>
      <div class="tk-tour-actions">
        <button type="button" class="btn btn-link btn-sm tk-tour-skip" data-tour-action="skip">Pular</button>
        <div class="tk-tour-nav-buttons">
          ${this._index > 0 ? '<button type="button" class="btn btn-outline-secondary btn-sm" data-tour-action="prev">Anterior</button>' : ""}
          <button type="button" class="btn btn-sm tk-tour-next-btn" data-tour-action="next">${isLast ? "Concluir" : "Próximo"}</button>
        </div>
      </div>
    `
  },

  // Sem alvo (passo de boas-vindas): centralizado na tela. Com alvo:
  // abaixo dele por padrão, ou acima se não couber, sempre dentro da
  // viewport (clamp horizontal).
  _positionTooltip(tooltip, target) {
    const margin = 16
    const { innerWidth, innerHeight } = window

    if (!target) {
      tooltip.style.top = "50%"
      tooltip.style.left = "50%"
      tooltip.style.transform = "translate(-50%, -50%)"
      return
    }

    tooltip.style.transform = "none"
    const rect = target.getBoundingClientRect()
    const tooltipRect = tooltip.getBoundingClientRect()

    let top = rect.bottom + TK_TOUR_SPOTLIGHT_PADDING + margin
    if (top + tooltipRect.height > innerHeight - margin) {
      top = rect.top - TK_TOUR_SPOTLIGHT_PADDING - margin - tooltipRect.height
    }
    top = Math.max(margin, Math.min(top, innerHeight - tooltipRect.height - margin))

    let left = rect.left + rect.width / 2 - tooltipRect.width / 2
    left = Math.max(margin, Math.min(left, innerWidth - tooltipRect.width - margin))

    tooltip.style.top = `${top}px`
    tooltip.style.left = `${left}px`
  }
}

document.addEventListener("turbo:load", () => {
  const autostart = document.getElementById("tk-tour-autostart")
  if (autostart?.dataset.autostart === "true") window.TkGuideTour.start()
})
