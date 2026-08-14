# syntax=docker/dockerfile:1
# check=error=true

# Imagem de produção, em 2 etapas (build → final) — a etapa final não
# carrega compilador nem código-fonte de gems, só o necessário pra rodar.
#
# ⚠️ O Gemfile deste projeto fixa `ruby "4.0.6"` (ver README, seção
# "Stack" — é a versão-alvo definida para o projeto). Se a tag
# `ruby:4.0.6-slim` ainda não existir no Docker Hub no momento em que você
# for buildar ("pull access denied"/"manifest unknown" neste FROM), builde
# apontando pra sua versão real disponível, ex.:
#   docker build --build-arg RUBY_VERSION=3.3.5 .
ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Pacotes de sistema necessários em tempo de execução.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libsqlite3-0 \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# --- Etapa de build -----------------------------------------------------
# Só existe pra compilar as gems e precompilar assets; é descartada no
# final, então o compilador/headers não vão pra imagem que roda em produção.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libsqlite3-dev \
      pkg-config \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# SECRET_KEY_BASE_DUMMY faz o Rails usar uma chave descartável só pra
# conseguir carregar o ambiente de produção e rodar o precompile — não é a
# chave usada em runtime (essa vem de verdade da env SECRET_KEY_BASE, ver
# docker-compose.yml/.env.example). Este projeto não tem
# config/master.key/credentials.yml.enc, então SECRET_KEY_BASE (env) é
# obrigatória em produção.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --- Etapa final ----------------------------------------------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000

# A rota /acessibilidade é pública (não exige login — ver
# app/controllers/pages_controller.rb) e sempre responde 200, por isso é
# usada aqui em vez de "/", que exigiria autenticação.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f "http://localhost:${PORT:-3000}/acessibilidade" || exit 1

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
