# frozen_string_literal: true

source 'https://rubygems.org'

ruby '4.0.6'

gem 'bootsnap', require: false
gem 'importmap-rails'
gem 'pg', '~> 1.5'
gem 'propshaft'
gem 'puma', '>= 6.0'
gem 'rails', '~> 8.1'
# Fila persistente de Active Job, no próprio PostgreSQL (ver
# config/environments/production.rb e a seção "Webhooks de saída" do
# README). Substitui o adapter :async, que guardava a fila na memória do
# processo web e perdia tudo que estivesse pendente num restart.
gem 'solid_queue'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# View layer
gem 'haml-rails'

# Autenticação e autorização
gem 'cancancan'
gem 'devise'

# Construção de filtros/ordenação (ver DemandasController#index e
# UsersController#index) — usado apenas como mecanismo interno de query;
# não expomos a sintaxe nativa do Ransack (params[:q][:attr_predicate]) na
# URL, para preservar o contrato simples já existente (q, status, sort,
# direction). Ver ransackable_attributes/ransackable_associations em
# Demanda e User.
gem 'ransack'

# Geração do PDF do relatório semanal (ver RelatoriosController). Prawn é
# puro Ruby (sem binário externo tipo wkhtmltopdf/Chrome headless, ao
# contrário de wicked_pdf/grover) — mais simples de instalar e de rodar
# em produção/Docker, e consistente com o resto do projeto (que evita
# dependências pesadas — ver, por ex., a ausência de um driver
# Capybara/JS no Gemfile).
gem 'prawn'
gem 'prawn-table'

# Prawn usa a lib "matrix" internamente (prawn/transformation_stack.rb).
# "matrix" saiu do conjunto de gems padrão do Ruby (deixou de vir
# embutida) a partir do Ruby 3.4 — sem declará-la aqui, `bundle exec` (ou
# `bin/rails` chamando Bundler.require) quebra com
# `LoadError: cannot load such file -- matrix` assim que o Prawn tenta
# carregar. Erro real, reproduzido rodando `rails db:migrate` no Ruby
# 4.0.6 do projeto.
gem 'matrix'

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'shoulda-matchers'

  # Style guide automatizado (ver .rubocop.yml). require: false porque só
  # é usado via linha de comando/CI, não precisa ser carregado pela app.
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'rails-controller-testing'
end
