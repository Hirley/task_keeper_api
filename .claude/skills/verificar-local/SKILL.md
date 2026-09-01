---
name: verificar-local
description: Roda RuboCop, zeitwerk:check e RSpec deste projeto em container, e sobe a app pra verificação no navegador. Use antes de qualquer commit, e sempre que precisar afirmar que algo passa — não há Ruby compatível instalado nesta máquina, então esta é a única forma de executar o código.
---

# Verificação local em container

Não há Ruby 4.0.6 nesta máquina (o `C:\Ruby32-x64` é 3.2.4 e o Bundler recusa). Todo o ciclo roda em container, espelhando o `.github/workflows/ci.yml`: `bundle lock --add-platform x86_64-linux` → `bundle install` → `db:prepare` → `zeitwerk:check` → `rspec`.

O código é **copiado** para dentro do container, não montado por volume. Duas razões: bind mount de caminho Windows em container Linux é lento, e o passo `add-platform` reescreve o `Gemfile.lock` — montado, isso sujaria o worktree.

Prefixe todo comando com `MSYS_NO_PATHCONV=1`. Sem isso o Git Bash converte `/app` em `C:/Program Files/Git/app` e o `docker run` falha.

## Ciclo rápido (containers já de pé)

```bash
MSYS_NO_PATHCONV=1 docker cp . tk-ruby:/app && MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test -e DB_HOST=tk-pg -e DB_USERNAME=postgres -e DB_PASSWORD=postgres -e DB_NAME=task_keeper_api_test -e SECRET_KEY_BASE=dummy -e CHROME_BIN=/usr/bin/chromium tk-ruby bash -c 'cd /app && bundle lock --add-platform x86_64-linux >/dev/null && bundle exec rubocop --format simple | tail -2 && bundle exec rspec 2>&1 | tail -4'
```

Leva ~20s. O `add-platform` está ali porque o `docker cp` sobrescreve o `Gemfile.lock` do container com o do worktree, que não tem a plataforma Linux. As gems ficam em `/usr/local/bundle`, fora do `/app`, então recopiar o código não obriga a reinstalar nada.

`CHROME_BIN` aponta os system specs (`spec/system`) para o Chromium do Debian — no runner do GitHub o binário é o `google-chrome`, que o Selenium acha sozinho, mas aqui não existe com esse nome. Sem a variável **a suíte inteira falha**, não só os cinco system specs: eles fazem parte do `bundle exec rspec` normal, de propósito, para que "rodar os testes" signifique a mesma coisa aqui e no CI.

Rodou uma migration? Acrescente `bin/rails db:migrate` antes do RSpec, senão o `maintain_test_schema!` recarrega o schema antigo e o RSpec aborta com "Migrations are pending".

**`docker cp` acrescenta e sobrescreve, mas nunca apaga.** Um arquivo removido aqui continua existindo no container e segue sendo lintado e executado — dá para ver um RuboCop vermelho ou uma contagem de exemplos maior que a real, por causa de um arquivo que não existe mais. Se os números não baterem, compare a contagem (`bundle exec rubocop` diz quantos arquivos inspecionou) e remova o resíduo com `docker exec tk-ruby rm -f /app/<caminho>`.

## Primeira vez (ou depois de `docker rm`)

```bash
MSYS_NO_PATHCONV=1 docker network create tk-test; MSYS_NO_PATHCONV=1 docker run -d --name tk-pg --network tk-test -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=task_keeper_api_test postgres:16-alpine && MSYS_NO_PATHCONV=1 docker run -d --name tk-ruby --network tk-test -w /app ruby:4.0.6-slim sleep infinity
```

Depois, dentro do `tk-ruby`: copie o código, remova o `/app/.git` (é um arquivo de worktree apontando para um caminho Windows que não existe lá), instale `build-essential` e `libpq-dev`, fixe o Bundler na versão do `Gemfile.lock` (`BUNDLED WITH`) e rode `bundle install`.

```bash
MSYS_NO_PATHCONV=1 docker cp . tk-ruby:/app && MSYS_NO_PATHCONV=1 docker exec tk-ruby bash -c 'rm -f /app/.git && apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev chromium chromium-driver >/dev/null 2>&1 && gem install bundler -v 4.0.18 --no-document >/dev/null && cd /app && bundle lock --add-platform x86_64-linux >/dev/null && bundle install --jobs 4 --retry 3 2>&1 | tail -2'
```

## Verificação no navegador

Obrigatória para mudança em JS, CSS, HAML ou CSP. Os system specs cobrem CSP e o alto contraste sobrevivendo ao Turbo — mas tour guiado, dropdown de busca, busca por voz e o widget do VLibras continuam sem spec, e são justamente os que só o olho pega.

Congele a imagem com as gems e suba a app numa porta publicada:

```bash
MSYS_NO_PATHCONV=1 docker commit tk-ruby tk-app:local && MSYS_NO_PATHCONV=1 docker run -d --name tk-web --network tk-test -p 3000:3000 -w /app -e RAILS_ENV=development -e DB_HOST=tk-pg -e DB_USERNAME=postgres -e DB_PASSWORD=postgres -e DB_NAME=task_keeper_api_development -e SECRET_KEY_BASE=dummy-dev-key tk-app:local bash -c 'bin/rails db:prepare && bin/rails db:seed && bin/rails server -b 0.0.0.0 -p 3000'
```

Sobe em `http://localhost:3000`. Para trocar só um arquivo sem reconstruir, `docker cp` o arquivo em `tk-web:/app/...` e `docker restart tk-web` (initializer não recarrega sozinho).

O que verificar:

- **console sem erros** — e leia numa aba nova, porque o console acumula mensagens de carregamentos anteriores e é fácil confundir erro antigo com atual;
- **o mesmo depois de uma navegação do Turbo Drive**, não só no primeiro load. O Turbo troca o `<body>` sem criar documento novo, e várias coisas só quebram no segundo passo;
- ao suspeitar que um erro é anterior à sua mudança, **prove**: desative a mudança só dentro do container (`mv` do initializer, por exemplo), reinicie e reproduza numa aba limpa.

Não é preciso autenticar para verificar o layout: a barra de acessibilidade, o Bootstrap e o VLibras ficam fora do bloco de usuário logado, e `/acessibilidade` e `/users/sign_in` são públicas. **Não faça login** — não digite senha em formulário.

## Encerrar

```bash
MSYS_NO_PATHCONV=1 docker rm -f tk-web tk-ruby tk-pg
```

## Quando o daemon está fora

`docker ps` falhando com `npipe:////./pipe/dockerDesktopLinuxEngine` significa Docker Desktop parado — ele já caiu no meio de uma sessão. Abrir o Docker Desktop resolve; a distro `docker-desktop` do WSL pode levar um tempo depois disso para sair de `Stopped`. Enquanto não voltar, **não afirme que algo passa**: diga que foi revisado, não executado.
