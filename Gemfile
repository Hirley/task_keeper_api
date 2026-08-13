source "https://rubygems.org"

ruby "4.0.6"

gem "rails", "~> 8.1"
gem "sqlite3", ">= 2.1"
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

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
end

group :development do
  gem "web-console"
end

group :test do
  gem "rails-controller-testing"
end
