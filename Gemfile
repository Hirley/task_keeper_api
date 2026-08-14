source "https://rubygems.org"

ruby "4.0.6"

gem "rails", "~> 8.1"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

# View layer
gem "haml-rails"

# Autenticação e autorização
gem "devise"
gem "cancancan"

# Construção de filtros/ordenação (ver DemandasController#index e
# UsersController#index) — usado apenas como mecanismo interno de query;
# não expomos a sintaxe nativa do Ransack (params[:q][:attr_predicate]) na
# URL, para preservar o contrato simples já existente (q, status, sort,
# direction). Ver ransackable_attributes/ransackable_associations em
# Demanda e User.
gem "ransack"

# Geração do PDF do relatório semanal (ver RelatoriosController). Prawn é
# puro Ruby (sem binário externo tipo wkhtmltopdf/Chrome headless, ao
# contrário de wicked_pdf/grover) — mais simples de instalar e de rodar
# em produção/Docker, e consistente com o resto do projeto (que evita
# dependências pesadas — ver, por ex., a ausência de um driver
# Capybara/JS no Gemfile).
gem "prawn"
gem "prawn-table"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"

  # Style guide automatizado (ver .rubocop.yml). require: false porque só
  # é usado via linha de comando/CI, não precisa ser carregado pela app.
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "rails-controller-testing"
end
