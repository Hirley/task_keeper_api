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
  # 12 em vez dos 6 do default do Devise. O mínimo importa mais aqui do
  # que num cadastro comum: não há autocadastro, então a PRIMEIRA senha
  # de todo usuário é digitada por um líder/admin em UsersController#create
  # (senha provisória) — e senha escolhida às pressas por terceiro tende
  # a ser curta e padronizada ("mudar123"). Com 6 caracteres permitidos,
  # essa senha é o elo mais fraco do sistema inteiro; ver também o
  # rate limit em Users::SessionsController, que é a outra metade dessa
  # proteção.
  config.password_length = 12..128
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

# Força as rotas a serem finalizadas no boot quando não há eager load —
# isto é, em teste e desenvolvimento. Sem isso, o PRIMEIRO POST
# /users/sign_in de um processo recém-iniciado falha com credenciais
# válidas, e o segundo funciona.
#
# A cadeia é esta:
#
#   1. Warden::Manager está no middleware, ANTES do router. Ao atender a
#      requisição ele monta um Warden::Proxy com uma cópia da config.
#   2. Quem registra as estratégias do Devise na config do Warden é
#      Devise.configure_warden! (ver devise/rails/routes.rb), e ele só
#      roda quando o RouteSet é finalizado — porque depende das mappings
#      criadas pelo devise_for.
#   3. Com rotas carregadas preguiçosamente (Rails 7.1+) e sem eager
#      load, essa finalização acontece DENTRO da primeira requisição, no
#      router — depois de o proxy do Warden já ter copiado a config.
#
# O resultado é um proxy com default_strategies vazio: o Warden não tem
# estratégia nenhuma para rodar, não chega a consultar o banco, e a
# resposta é 401 (que o responder do Devise traduz em 422). Medido:
# na primeira requisição, default_strategies={}; na segunda,
# {user: [:rememberable, :database_authenticatable]}.
#
# Produção não é afetada, porque lá config.eager_load é true e as rotas
# já estão finalizadas antes da primeira requisição — daí a guarda
# abaixo, que evita pagar esse custo onde ele não resolve nada.
#
# Isso também explicava uma falha intermitente do CI: a suíte só quebrava
# quando a ordem aleatória do RSpec punha o único exemplo de login
# bem-sucedido como primeira requisição do processo (ver
# spec/devise_warden_boot_spec.rb, que guarda essa invariante sem
# depender de ordem).
Rails.application.config.after_initialize do
  Rails.application.reload_routes! unless Rails.application.config.eager_load
end
