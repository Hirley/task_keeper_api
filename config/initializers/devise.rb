# frozen_string_literal: true

# Configuração mínima do Devise para a API + interface web do task_keeper_api.
Devise.setup do |config|
  config.mailer_sender = 'no-reply@task-keeper.local'

  require 'devise/orm/active_record'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # Sem isso, uma tentativa de login inválida faz o Devise re-renderizar
  # a tela de login (via Warden::FailureApp#recall, chamando
  # SessionsController#new internamente) com status 200 — e um POST de
  # formulário que responde 200 sem ser um redirect quebra o Turbo Drive
  # (a interface web usa turbo-rails): o console do navegador acusa
  # "Error: Form responses must redirect to another location" e a tela
  # trava sem nenhum feedback visível pro usuário. `error_status:
  # unprocessable_entity` faz esse mesmo re-render responder com 422 em
  # vez de 200 — o Turbo Drive trata 4xx/5xx como "renderizar a resposta
  # no lugar" (é assim que erros de validação em geral funcionam com
  # Turbo), então a mensagem de erro volta a aparecer normalmente.
  # `redirect_status: see_other` (303) é o equivalente pro caminho de
  # redirect (ex.: depois de um sign_out). Este é o valor que o próprio
  # gerador do Devise já recomenda para apps com Hotwire/Turbo desde a
  # v5 — só não é o default da gem ainda por compatibilidade.
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other

  # Não há autocadastro: apenas o líder pode criar novos usuários,
  # por isso o módulo :registerable não é habilitado no model User.
end
