// Entry point para importmap-rails.
//
// Carrega o Turbo para que os data-turbo-confirm (usados, por exemplo, no
// botão "Excluir" de app/views/demandas/index.html.haml) mostrem o alerta
// de confirmação antes de enviar o form de exclusão.
import "@hotwired/turbo-rails"
