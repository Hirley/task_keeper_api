# syntax=docker/dockerfile:1
# check=error=true

# Imagem de produção, em 2 etapas (build → final) — a etapa final não
# carrega compilador nem código-fonte de gems, só o necessário pra rodar.
#
# ruby:4.0.6-slim existe de verdade (confirmado: Gemfile.lock deste
# projeto tem "RUBY VERSION ruby 4.0.6" e "BUNDLED WITH 4.0.18", gerados
# por um `bundle install` real). Ainda assim, se sua versão de Ruby local
# for outra, dá pra apontar pra ela via --build-arg:
#   docker build --build-arg RUBY_VERSION=3.3.5 .
ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Pacotes de sistema necessários em tempo de execução.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libpq5 \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# --- Etapa de build -----------------------------------------------------
# Só existe pra compilar as gems e precompilar assets; é descartada no
# final, então o compilador/headers não vão pra imagem que roda em produção.
FROM base AS build

# Versão do Bundler usada para gerar o Gemfile.lock deste projeto (ver
# "BUNDLED WITH" no próprio arquivo) — fixar isso evita que a versão do
# Bundler pré-instalada na imagem base (que pode ser outra) tente
# re-resolver ou reclamar do lockfile. Se o Gemfile.lock for regenerado
# com outra versão do Bundler, ajuste aqui também.
ARG BUNDLER_VERSION=4.0.18

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      pkg-config \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copia o projeto inteiro ANTES do bundle install (em vez do padrão
# "COPY Gemfile* primeiro, pra cachear a camada do bundle install
# separado do código"): como o passo abaixo precisa MODIFICAR o
# Gemfile.lock (adicionar a plataforma Linux — ver comentário logo
# abaixo), copiar o resto do código DEPOIS sobrescreveria esse
# Gemfile.lock corrigido com a versão original (sem a plataforma) que
# veio do host, fazendo a correção "sumir" silenciosamente e só quebrar
# num passo posterior (foi exatamente isso que aconteceu numa versão
# anterior deste Dockerfile — ver histórico do PR #26). Copiando tudo de
# uma vez só, isso não acontece — o custo é que qualquer mudança no
# código também invalida o cache do bundle install, não só mudanças no
# Gemfile/Gemfile.lock.
COPY . .

# Normaliza terminadores de linha dos scripts em bin/ para LF. Os blobs
# no repositório já estão em LF (ver .gitattributes), mas quem
# desenvolve no Windows costuma ter `core.autocrlf=true` no Git (é o
# padrão sugerido pelo próprio Git nesse SO), que converte esses
# arquivos para CRLF no checkout local — e o `docker build` copia o
# contexto direto do disco (não do objeto Git), então a versão CRLF vai
# pro container. O shebang `#!/usr/bin/env ruby` então é interpretado
# como `ruby\r`, que não existe, e a execução falha com "No such file
# or directory". `.gitattributes` evita isso em checkouts novos, mas
# não corrige um checkout já existente sem um passo manual do usuário
# (`git add --renormalize .` ou re-clonar) — este `sed` cobre esse caso
# sem depender disso.
RUN sed -i 's/\r$//' bin/*

# O Gemfile.lock deste projeto foi gerado originalmente numa máquina
# Windows — a seção PLATFORMS só tinha "x64-mingw-ucrt", sem a
# plataforma Linux. Sem isso, `bundle install` (e qualquer `bundle exec`
# depois, já que o Bundler valida a plataforma atual contra o lockfile
# toda vez) falha dentro do container ao tentar resolver as gems com
# extensão nativa (pg, nokogiri) pra Linux. `bundle lock --add-platform`
# corrige isso no lockfile da própria imagem (build reproduzível, sem
# depender de o Gemfile.lock commitado já ter sido corrigido).
RUN gem install bundler --version "${BUNDLER_VERSION}" --no-document && \
    bundle "_${BUNDLER_VERSION}_" lock --add-platform x86_64-linux && \
    BUNDLE_DEPLOYMENT=1 bundle "_${BUNDLER_VERSION}_" install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

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
