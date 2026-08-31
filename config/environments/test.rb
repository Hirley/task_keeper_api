# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  # Eager loading em CI (ENV["CI"].present?) foi tentado para pegar erros
  # de autoload cedo, mas expôs um FrozenError ("can't modify frozen
  # Array: [...autoload paths de devise/actionmailbox/activestorage...]").
  #
  # Causa raiz (investigada com bundle/rubocop/rails rodando localmente):
  # não é um bug real de autoload/Zeitwerk — é `Rails.application.initialize!`
  # não sendo seguro pra rodar de novo no mesmo processo. rails_helper.rb
  # roda `require_relative "../config/environment"` uma vez só (Ruby cacheia
  # `require` por arquivo), mas só cacheia se o require *não* levantar. Se
  # o boot falha por qualquer motivo depois que o Rails já travou
  # (`.freeze`) o array global de autoload paths (isso acontece cedo, em
  # `Rails::Engine#set_autoload_paths`/`Finisher#setup_main_autoloader`,
  # bem antes de qualquer erro de configuração tardio), o próximo arquivo
  # de spec que fizer `require "rails_helper"` reexecuta o arquivo do
  # zero — incluindo tentar de novo `Rails.application.initialize!` — só
  # que agora contra um array já congelado da tentativa anterior. Daí o
  # FrozenError, repetido a cada spec seguinte carregado (foi exatamente
  # esse padrão no log da CI: o mesmo FrozenError "em cascata" pra vários
  # specs, não um erro isolado).
  #
  # `config.eager_load = true` aqui reintroduziria esse mesmo risco: uma
  # única falha tardia de boot (de qualquer causa, não só a antiga do
  # storage.yml) corrompe todas as tentativas seguintes de carregar specs
  # no mesmo processo do RSpec. Por isso eager load continua desligado em
  # teste — mas o objetivo original (pegar erro de autoload cedo, sem
  # esperar o deploy) é coberto sem esse risco pela tarefa própria do
  # Rails pra isso, isolada num processo à parte: `bin/rails
  # zeitwerk:check` (ver o passo "Zeitwerk check" no CI, antes do RSpec).
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  # :memory_store, e não :null_store, porque o rate_limit do Rails conta
  # as tentativas no cache — com :null_store o contador nunca sobe e o
  # throttle de AuthThrottling ficaria sem teste nenhum. Nada mais na
  # aplicação usa Rails.cache, então isso não liga cache de verdade em
  # lugar nenhum; o rails_helper limpa o store antes de cada exemplo pra
  # que um contador não vaze de um teste pro outro.
  config.cache_store = :memory_store

  config.action_dispatch.show_exceptions = :none

  config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test

  # Sem isto valeria o default do Rails, :async, que roda o job de verdade
  # numa thread de fundo durante o teste — contra o mesmo banco, dentro de
  # uma transação que o RSpec vai desfazer, e (no caso de WebhookDelivery)
  # com chance de tentar rede de verdade. Hoje isso quase nunca dispara,
  # porque os specs dublam WebhookDeliveryJob.perform_later, mas é
  # acidente e não desenho. O adapter :test também é o que permite
  # verificar o retry de WebhookDeliveryJob sem esperar backoff real.
  config.active_job.queue_adapter = :test

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test
  # Necessário pra gerar URLs fora de uma requisição (o e-mail de
  # redefinição de senha do Devise e Users::SendPasswordResetViaTelegram,
  # que roda fora de um controller) — sem isso, edit_user_password_url
  # levanta "Missing host to link to!".
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  config.active_support.deprecation = :stderr

  config.action_controller.raise_on_missing_callback_actions = true
end
