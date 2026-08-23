# Task Keeper API

Aplicação Ruby on Rails full-stack (API REST + interface web) para times pequenos organizarem e acompanharem demandas do dia a dia: quem é responsável por quê, o que está atrasado, e um jeito rápido de saber "o que precisa da minha atenção agora?".

Três papéis com permissões diferentes (executor/líder/admin), autenticação e autorização (Devise + CanCanCan), notificação automática de atraso via Telegram, webhooks de saída (Slack/Teams/Discord/n8n), relatório semanal em PDF, e uma API JSON versionada ao lado da tela web — tudo com suíte de testes automatizados, CI (RuboCop + RSpec + build/publish da imagem Docker) e deploy em container.

**Rodando em produção:** ver seção "Docker" — imagem publicada automaticamente em `ghcr.io/hirley/task_keeper_api` a cada merge em `main`.

## Stack

- Ruby 4.0.6 · Ruby on Rails 8.1 · PostgreSQL
- Devise (autenticação) + CanCanCan (autorização, papéis executor/líder/admin)
- HAML + Bootstrap (interface web) + Ransack (filtro/ordenação — ver "Identidade visual e busca/paginação")
- Prawn + prawn-table (PDF do relatório semanal — ver "Relatório semanal")
- RSpec + FactoryBot + Shoulda Matchers (testes) · RuboCop (estilo)
- Docker + GitHub Actions (CI: lint, testes, build e publish da imagem)

## Regras de negócio

- Existem três papéis de usuário: **executor**, **líder** e **admin**.
- Todos os papéis podem cadastrar novas demandas.
- Líder e admin podem editar ou excluir uma demanda já existente.
- O cadastro de demanda traz a data atual por padrão, mas permite escolher outra; após criada, só líder/admin pode alterar essa data.
- Líder e admin podem cadastrar, alterar a permissão (papel) e excluir usuários (não há autocadastro).
- Um usuário com permissão de gerenciar acessos não pode excluir a própria conta, nem excluir um usuário que já tenha demandas cadastradas.
- **Admin é o único papel** que cadastra o **Chat ID do Telegram** de um usuário e que cadastra/gerencia **Webhooks de saída** — nem o líder tem esses dois privilégios, mesmo tendo `can :manage, :all` para o resto (ver `app/models/ability.rb`).

## Setup local

Requer um PostgreSQL rodando (localmente instalado, ou via `docker compose up db` — ver seção "Docker"). Por padrão a aplicação espera `localhost:5432`, usuário/senha `postgres`/`postgres` (ver `config/database.yml` e `.env.example`); ajuste `DB_HOST`/`DB_USERNAME`/`DB_PASSWORD`/`DB_NAME` (ou `DATABASE_URL`) se o seu Postgres local usa outras credenciais.

```bash
cp .env.example .env   # ajuste as credenciais do Postgres se precisar
bundle install
bin/rails db:prepare
bin/rails db:seed   # cria um usuário admin, um líder e um executor de exemplo
bin/rails server
```

Se você já tinha o banco criado localmente antes de alguma migration nova (ex.: campo **Data** em demandas, **Chat ID do Telegram**), rode `bin/rails db:migrate` para aplicar o que estiver pendente. Depois de puxar mudanças no `Gemfile`, rode `bundle install` de novo para atualizar o `Gemfile.lock`.

Rodar a suíte de testes:

```bash
bundle exec rspec
```

Rodar o RuboCop (estilo de código — ver `.rubocop.yml`):

```bash
bundle exec rubocop
```

Usuários de exemplo criados pelo `db:seed`:

| Papel    | E-mail                        | Senha        |
|----------|--------------------------------|--------------|
| admin    | admin@task-keeper.local        | senha123456  |
| líder    | lider@task-keeper.local        | senha123456  |
| executor | executor@task-keeper.local     | senha123456  |

## Docker

O `Dockerfile` builda uma imagem de produção em 2 etapas (build → final): a etapa final não carrega compilador nem código-fonte de gems, só o necessário para rodar a aplicação — Puma servindo direto (sem Thruster/Kamal, que não fazem parte do Gemfile deste projeto).

Pra subir localmente, um único comando, sem nenhum passo manual antes:

```bash
docker compose up --build
```

Isso sobe a imagem de produção **e** um serviço `db` (PostgreSQL) localmente, na porta `3000`, com os dados do banco persistidos num volume nomeado (sobrevivem a `docker compose down`, mas não a `docker compose down -v`). O `docker-compose.yml` já traz um `SECRET_KEY_BASE` padrão pra esse uso local/demo (só copie `.env.example` para `.env` se quiser sobrescrever algum valor). Não é um ambiente de desenvolvimento com hot-reload — para isso, continue usando `bundle install && rails server` (apontando pro serviço `db` ou pra um Postgres local), como na seção anterior.

Também dá pra usar a imagem já publicada em vez de buildar localmente (ver seção "Integração contínua"):

```bash
docker pull ghcr.io/hirley/task_keeper_api:latest
```

Sem `docker compose` (conectando a um PostgreSQL já existente em outro lugar):

```bash
docker build -t task_keeper_api .
docker run -p 3000:3000 \
  -e SECRET_KEY_BASE=$(bin/rails secret) \
  -e DATABASE_URL=postgresql://usuario:senha@host:5432/nome_do_banco \
  task_keeper_api
```

`bin/docker-entrypoint` roda `bin/rails db:prepare` (idempotente) toda vez que o container sobe, antes de iniciar o Puma — então o banco é criado/migrado automaticamente, sem passo manual (mas o PostgreSQL em si precisa já estar de pé e acessível; o Dockerfile não sobe um banco dentro do próprio container da aplicação).

Este projeto não tem `config/master.key`/`config/credentials.yml.enc`, então `SECRET_KEY_BASE` (variável de ambiente) é obrigatória em produção — sem ela, o container não sobe. As variáveis de conexão com o banco (`DATABASE_URL` ou `DB_HOST`/`DB_PORT`/`DB_USERNAME`/`DB_PASSWORD`/`DB_NAME`) e as demais (`TELEGRAM_BOT_TOKEN`, `APP_HOST`, `RAILS_MAX_THREADS`) são opcionais/têm default; ver `.env.example` para a lista completa e o que cada uma faz.

**Sobre a plataforma do `Gemfile.lock`**: o lockfile deste projeto foi gerado originalmente numa máquina Windows — a seção `PLATFORMS` só tem `x64-mingw-ucrt`, sem a plataforma Linux. Sem isso, `bundle install` falha dentro de um container Linux ao tentar resolver as gems com extensão nativa (`pg`, `nokogiri`). O `Dockerfile` já corrige isso sozinho (roda `bundle lock --add-platform x86_64-linux` antes do `bundle install`, dentro da própria imagem), então não é preciso fazer nada manualmente por causa disso — mas é bom saber que esse ajuste existe, caso apareça algum erro de plataforma ao rodar `bundle install` fora do Docker também (nesse caso, `bundle lock --add-platform x86_64-linux` resolve, e o mesmo vale se você desenvolver num Mac Apple Silicon: `bundle lock --add-platform arm64-darwin`).

O build é validado automaticamente a cada push/PR pelo CI (ver seção "Integração contínua"). Durante o desenvolvimento, dois bugs reais de build já apareceram e foram corrigidos:

1. **`COPY . .` sobrescrevendo o `Gemfile.lock` corrigido**: rodava depois do `bundle lock --add-platform`, apagando silenciosamente o ajuste de plataforma antes do `bootsnap precompile app/ lib/` seguinte (`bundle exec` revalida a plataforma a cada chamada). Corrigido copiando o projeto inteiro antes de mexer no `Gemfile.lock`.
2. **CRLF em `bin/*`**: quem desenvolve no Windows normalmente tem `core.autocrlf=true` no Git, que converte os scripts de `bin/` (LF no repositório) para CRLF no checkout local; como `docker build` copia o contexto direto do disco (não do objeto Git), o CRLF ia parar no container e o shebang `#!/usr/bin/env ruby` de `bin/rails` virava `ruby\r` — `env: 'ruby\r': No such file or directory`. Corrigido normalizando `bin/*` para LF em tempo de build (`sed -i 's/\r$//' bin/*`, logo após o `COPY . .`), além de um `.gitattributes` (`* text=auto eol=lf`) pra evitar isso em checkouts novos.

## Integração contínua

`.github/workflows/ci.yml` roda no GitHub Actions em todo push para `main` e em toda pull request, com três jobs:

- **rubocop** — `bundle exec rubocop` (usa o `.rubocop.yml` já existente no repositório);
- **rspec** — sobe um serviço `postgres:16-alpine`, roda `bin/rails db:prepare`, depois `bin/rails zeitwerk:check` (eager load isolado num processo à parte, só pra pegar erro de autoload cedo — ver comentário em `config/environments/test.rb` sobre por que isso não é feito via `config.eager_load = true` no ambiente de teste) e por fim `bundle exec rspec` contra o banco `task_keeper_api_test`;
- **docker** — builda a imagem de produção (`docker/build-push-action`); só roda depois que `rubocop` e `rspec` passam. Em pull request, só valida que o `Dockerfile` builda (sem publicar). Em push pra `main`, publica a imagem no GitHub Container Registry (`ghcr.io/hirley/task_keeper_api`), usando o `GITHUB_TOKEN` automático do Actions — não exige nenhum secret configurado manualmente. Cada build fica marcado com duas tags: `latest` e o SHA do commit (`sha-<commit completo>`), pra sempre dar pra rastrear exatamente qual código está publicado.

⚠️ **Passo manual único**: por padrão, um pacote novo no GHCR nasce privado, mesmo em repositório público — depois do primeiro push em `main` que publicar a imagem, é preciso ir em *Package settings* (na página do pacote em `github.com/Hirley?tab=packages`) e trocar a visibilidade pra pública, se quiser puxar a imagem (`docker pull`) sem autenticação.

`SECRET_KEY_BASE` no workflow é um valor fixo só para o boot da aplicação em CI (não é usado em nenhum ambiente real — produção continua exigindo a variável de ambiente própria, como descrito na seção "Docker"). As demais variáveis de banco seguem o mesmo padrão de `.env.example`/`config/database.yml`.

## Cobertura de testes

A suíte RSpec cobre:

- **Models**: `User` e `Demanda` (`spec/models`), incluindo a validação do `telegram_chat_id` e o reset de `atraso_notificado_em`;
- **Política de autorização**: `Ability` (`spec/models/ability_spec.rb`), validando cada combinação de papel (executor/líder/admin) × ação para `Demanda`, `User` e `WebhookSubscription`;
- **Serviços** (`spec/services`): `TelegramNotifier` — mensagem, envio (incluindo `#enviar_documento`, usado pelo relatório semanal) e os casos de "não enviar" (sem token, sem chat_id, erro de rede), usando um dublê de transporte HTTP injetado no serviço (sem depender de gem de mock de rede); `WebhookDelivery`/`WebhookDispatcher` — montagem do payload, entrega (com o mesmo padrão de dublê de transporte), e quais assinaturas são notificadas por evento; `Users::Destroy` — a regra de exclusão de usuário (exclusão da própria conta/demandas vinculadas), testada uma única vez e reaproveitada pela tela web e pela API; `Relatorios::Semanal` — período considerado, filtro por período/status das demandas criadas/concluídas, contagens e carga por responsável;
- **Job** (`spec/jobs`): `WebhookDeliveryJob` — busca a assinatura e delega a entrega, sem quebrar se ela já não existir mais;
- **Tarefa agendada**: a rake task `demandas:notificar_atrasos` (`spec/tasks`) — idempotência, filtro por status/data/chat_id cadastrado;
- **API** (`spec/requests/api/v1`): `demandas` e `users`;
- **Telas web** (`spec/requests`): `demandas` (menu Demandas, incluindo filtro por múltiplos status/termos), `users` (menu Acessos, incluindo filtro múltiplo, ordenação por todas as colunas, e a restrição de `telegram_chat_id` a admin), `webhooks` (menu Webhooks — acesso restrito ao admin, cadastro/edição/exclusão, bloqueio de URL privada/local), `dashboard` (painel inicial/Início), `relatorios` (menu Relatórios — acesso restrito a líder/admin, download do PDF, envio por Telegram) e a página pública `/acessibilidade`;
- **Traduções pt-BR** (`spec/requests/devise_i18n_spec.rb`): regressão para a mensagem `Translation missing` do Devise (ver seção "Mensagens em pt-BR").
- **Compatibilidade do Devise com Turbo Drive** (`spec/requests/devise_turbo_spec.rb`): regressão para um login inválido responder `200` em vez de `422` (ver "Devise + Turbo Drive" abaixo).

Cenários validados explicitamente:

- um `executor` consegue criar uma demanda (via tela ou API), mas recebe `403`/é redirecionado ao tentar atualizar ou excluir;
- líder e admin conseguem criar, atualizar e excluir demandas;
- líder e admin conseguem listar/criar/excluir usuários, tanto pela tela `/users` quanto por `/api/v1/users` — mas só admin consegue definir o `telegram_chat_id` de um usuário (um líder que tenta é ignorado silenciosamente, sem erro);
- só admin acessa `/webhooks` — um líder que tenta é redirecionado, do mesmo jeito que um executor;
- um usuário com permissão de gerenciar acessos não consegue excluir a própria conta, nem um usuário com demandas vinculadas;
- o botão "Excluir" (demandas e usuários) carrega o Turbo e mostra o alerta de confirmação antes de enviar o form;
- uma demanda atrasada é notificada uma única vez no Telegram, e um novo aviso só é enviado se ela atrasar de novo depois de deixar de estar atrasada;
- a API rejeita com `415` qualquer `POST`/`PATCH`/`DELETE` sem `Content-Type: application/json` (proteção contra CSRF — ver seção "Endpoints principais"), sem afetar `GET`;
- ao tentar acessar uma tela protegida sem login, ou ao errar e-mail/senha, a mensagem aparece traduzida em pt-BR (não `Translation missing` — ver seção "Mensagens em pt-BR").

O que **não** tem cobertura automatizada, e por quê: interações que são só JavaScript/CSS (tamanho de fonte, alto contraste, o tooltip de ajuda do Chat ID) não têm teste, porque o `Gemfile` não inclui um driver Capybara/JS — foram verificadas manualmente (incluindo screenshots) antes de cada merge.

## Endpoints principais

| Verbo  | Rota                     | Quem pode acessar             |
|--------|---------------------------|--------------------------------|
| GET    | `/api/v1/demandas`        | qualquer usuário autenticado   |
| GET    | `/api/v1/demandas/:id`    | qualquer usuário autenticado   |
| POST   | `/api/v1/demandas`        | qualquer usuário autenticado   |
| PATCH  | `/api/v1/demandas/:id`    | líder ou admin                 |
| DELETE | `/api/v1/demandas/:id`    | líder ou admin                 |
| GET    | `/api/v1/users`           | líder ou admin                 |
| GET    | `/api/v1/users/:id`       | líder ou admin                 |
| POST   | `/api/v1/users`           | líder ou admin (campo `telegram_chat_id` só é salvo se quem cadastra é admin) |
| DELETE | `/api/v1/users/:id`       | líder ou admin                 |

Toda ação de escrita (`POST`/`PATCH`/`DELETE`) exige o header `Content-Type: application/json` — uma requisição sem esse header recebe `415 Unsupported Media Type`. Isso não é um capricho de formato: essa API autentica por sessão (cookie do Devise) e tem o token CSRF desativado (`Api::V1::BaseController`), então exigir `application/json` é o que impede um `<form>` HTML comum de outro site de forjar uma requisição usando a sessão já autenticada do usuário — um formulário nunca consegue definir esse Content-Type, só `application/x-www-form-urlencoded`, `multipart/form-data` ou `text/plain`.

## Painel inicial (dashboard)

A home (`/`, menu "Início") é um painel com uma visão geral das demandas, pensado para responder duas perguntas diferentes: "o que precisa da minha atenção agora?" e "como está a equipe?" — nessa ordem de prioridade:

- KPIs no topo: total de demandas e quantas estão em cada status;
- **Minhas demandas**: as demandas do próprio usuário logado, ordenadas por urgência (atrasada primeiro, depois o que vence antes); cada uma tem um badge de prazo (`Atrasada há N dias`, `Vence hoje`, `Vence amanhã`, `Vence em N dias`) — um canal separado do badge de status, porque "em que fase está" e "está no prazo?" são informações diferentes;
- **Atividade recente**: últimas demandas criadas por toda a equipe;
- **Distribuição por status**: uma única barra empilhada (não faz sentido um gráfico maior para 3 fatias) com a proporção pendente/em andamento/concluída;
- **Prazos**: quantas demandas (de toda a equipe) estão atrasadas, vencem hoje, ou vencem nos próximos `DashboardController::PRAZO_PROXIMO_DIAS` dias (3 por padrão);
- **Carga por responsável**: quantas demandas abertas (não concluídas) cada pessoa tem, da maior carga para a menor — visível pros três papéis, já que qualquer usuário autenticado já enxerga todas as demandas na listagem;
- **Equipe** (só pra líder e admin): contagem de admins/líderes/executores, com atalho para `/users`.

Todos os dados vêm do banco (nada é fixo/mockado) e respeitam a mesma autorização já usada na listagem de demandas (`Demanda.accessible_by(current_ability)`).

## Notificação de atraso via Telegram

Quando uma demanda de um executor fica atrasada (data no passado e ainda não concluída — o mesmo critério já usado no badge "Atrasada há N dias" do painel inicial), o app pode avisar o responsável por mensagem no Telegram. É opt-in por usuário e não depende de nenhum serviço externo pago.

**Configuração:**

1. Crie um bot conversando com o [@BotFather](https://t.me/BotFather) no Telegram (`/newbot`) e copie o token gerado.
2. Configure a variável de ambiente `TELEGRAM_BOT_TOKEN` com esse token (no Railway: aba **Variables** do serviço).
3. Cada usuário que quiser receber avisos descobre o próprio `chat_id` com o bot [@userinfobot](https://t.me/userinfobot) — passo a passo pelo celular ou computador: abra a barra de pesquisa do Telegram, digite `@userinfobot`, selecione o bot oficial nos resultados, toque em Começar (ou envie `/start`) e copie o número exibido no campo **Id**.
4. O **admin** cadastra esse `chat_id` no campo **Chat ID do Telegram** ao criar ou editar o usuário em `/users` — o próprio formulário tem um ícone ⓘ ao lado do campo com esse mesmo passo a passo, em forma de tooltip. É o único campo do formulário exclusivo do admin: nem o líder (que também cadastra/edita usuários) vê ou edita esse campo.

**Como funciona:**

- `TelegramNotifier` (`app/services/telegram_notifier.rb`) monta a mensagem e chama a API do Telegram (`sendMessage`) via `Net::HTTP` puro, sem depender de nenhuma gem adicional.
- A mensagem é empática e objetiva: cita o título da demanda e há quantos dias está atrasada, sem tom de cobrança, e diz o que fazer a seguir (atualizar o status, ou avisar o líder se precisar de mais tempo/ajuda).
- Como "ficar atrasada" é um estado que muda com o tempo (não com uma ação do usuário), o envio não acontece automaticamente na aplicação — é a tarefa `bin/rails demandas:notificar_atrasos` (`lib/tasks/telegram_notifications.rake`) que precisa rodar periodicamente (ex.: 1x ao dia). No Railway, isso é feito criando um segundo serviço do tipo **Cron Job** no mesmo projeto, rodando esse comando.
- Cada atraso é notificado **uma única vez** (campo `Demanda#atraso_notificado_em`) — se a demanda deixar de estar atrasada (data adiada ou marcada como concluída) e depois atrasar de novo, um novo aviso é enviado.
- Sem `TELEGRAM_BOT_TOKEN` configurado, ou sem `telegram_chat_id` no usuário, a notificação é simplesmente pulada (não é um erro).

## Webhooks de saída

Além do Telegram, o **admin** pode cadastrar webhooks genéricos em `/webhooks` — uma URL que recebe um `POST` com JSON toda vez que um dos eventos escolhidos acontece. Serve tanto pra notificar um canal de chat (Slack/Teams/Discord, apontando pra um webhook incoming deles) quanto pra disparar uma automação no-code (n8n, Knime) — o mecanismo é o mesmo, só muda quem recebe o `POST`.

**Eventos disponíveis:** `demanda_criada`, `demanda_concluida`, `demanda_excluida` (disparados por callbacks no model `Demanda` — cobrem tanto a tela web quanto a API) e `relatorio_gerado` (disparado só quando o relatório semanal é efetivamente baixado ou enviado por Telegram, não a cada visita à pré-visualização).

**Como funciona:**

- `WebhookSubscription` (`app/models/webhook_subscription.rb`) guarda a URL e os eventos escolhidos (array nativo do Postgres). Um webhook pode ser pausado (`active: false`) sem precisar excluir o cadastro.
- `WebhookDispatcher` (`app/services/webhook_dispatcher.rb`) encontra as assinaturas ativas que escutam o evento e enfileira `WebhookDeliveryJob` pra cada uma — em background (adapter `:async` padrão do Rails; este projeto não tem Sidekiq/Solid Queue configurado), pra não travar a request original no tempo de resposta de um serviço de terceiro.
- `WebhookDelivery` (`app/services/webhook_delivery.rb`) faz o `POST` de fato, com timeout curto (5s). Um endpoint de terceiro fora do ar, lento ou respondendo erro não derruba nada — só loga e segue; não há retry.
- **Proteção contra SSRF**: a URL cadastrada é validada no momento do cadastro/edição — o host é resolvido e endereços de rede privada/local (`127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16` e as faixas IPv6 equivalentes) são recusados, pra reduzir o risco do admin apontar um webhook pra um serviço interno da própria rede.

## Relatório semanal

Tela em `/relatorios` (menu **Relatórios**), visível pra líder e admin (`can? :read, :relatorio` — ver `app/models/ability.rb`), com um resumo dos últimos 7 dias corridos (hoje e os 6 dias anteriores, não a semana de calendário): demandas criadas na semana, demandas concluídas na semana, situação atual por status, atrasadas, e carga atual por responsável. Os dados são montados por `Relatorios::Semanal` (`app/services/relatorios/semanal.rb`) e reutilizados tanto pela tela de pré-visualização quanto pelo PDF.

**Geração é sob demanda** — quem acessa decide quando gerar, não há envio automático agendado (diferente do lembrete de atraso, que roda periodicamente por natureza). Duas formas de obter o relatório, ambas na mesma tela:

- **Baixar PDF** (`GET /relatorios/semanal.pdf`): gerado com [Prawn](https://github.com/prawnpdf/prawn) + `prawn-table` (`Relatorios::SemanalPdf`, em `app/services/relatorios/semanal_pdf.rb`) — puro Ruby, sem depender de um binário externo tipo wkhtmltopdf ou Chrome headless (mesma filosofia de manter dependências leves já usada no restante do projeto). Dispara o webhook `relatorio_gerado` (ver "Webhooks de saída").
- **Enviar por Telegram** (`POST /relatorios/enviar_telegram`): envia o mesmo PDF como documento (`sendDocument` da API do Telegram) pro Chat ID de **quem pediu** — não pra outros usuários, mesmo que também tenham Chat ID cadastrado. Reaproveita a mesma configuração (`TELEGRAM_BOT_TOKEN`) e o mesmo padrão de "sem token/chat_id configurado não é erro, só não envia" já usado pelo lembrete de atraso; ver `TelegramNotifier#enviar_documento`. Também dispara `relatorio_gerado`.

⚠️ Como o model `Demanda` não tem um campo dedicado de "concluída em", "demandas concluídas na semana" é uma aproximação baseada em `updated_at` das demandas já concluídas — pode incluir uma demanda que só teve outro campo editado depois de já estar concluída, não necessariamente a que virou concluída nesta semana exata. Documentado também no comentário de `Relatorios::Semanal#concluidas_no_periodo`.

## Tela web de demandas

Além da API, há uma tela em `/demandas` (menu "Demandas" no topo) para uso pelos usuários autenticados:

- os três papéis veem o botão **Nova demanda** e podem cadastrar;
- só líder e admin veem a coluna **Ações**, com os botões **Editar** e **Excluir** em cada linha;
- se um executor tentar acessar `/demandas/:id/edit` diretamente, é redirecionado com aviso de permissão negada;
- o botão **Excluir** pede confirmação (`data-turbo-confirm`, via Turbo) antes de enviar o form de exclusão;
- um formulário de busca (com autocomplete por título já cadastrado + filtro por status) e paginação (10 por página);
- as colunas **Título**, **Data**, **Status**, **Responsável** e **Criada em** são clicáveis e ordenam a listagem (clicar de novo inverte a direção); o filtro de busca preserva a ordenação escolhida;
- o cadastro tem um campo **Data**, preenchido por padrão com a data atual, mas que pode ser alterado para outra data no momento da criação; depois que a demanda já existe, só líder/admin pode alterar essa data (mesma regra de edição das demais informações da demanda).

## Tela web de Acessos

Há também uma tela em `/users` (menu "Acessos" no topo, visível a líder e admin) para cadastrar novos usuários e alterar a permissão (papel executor/líder/admin) de usuários já existentes:

- só líder e admin veem o menu "Acessos" e conseguem acessar `/users`; um executor que tentar acessar diretamente é redirecionado com aviso de permissão negada;
- o cadastro de um novo usuário exige nome, e-mail, senha e a permissão (executor, líder ou admin) — não há autocadastro;
- a edição permite alterar nome, e-mail e a permissão de um usuário existente (a troca de senha continua pelo fluxo de "esqueci minha senha" do Devise);
- **o campo Chat ID do Telegram só aparece pra quem está logado como admin** — nem no formulário, nem na edição, um líder vê ou consegue alterar esse campo de outro usuário (reforçado também do lado do servidor, não só escondido na tela);
- líder e admin também podem **excluir** outros usuários (com confirmação via Turbo). Duas travas de segurança: não dá pra excluir a própria conta, nem excluir um usuário que já tenha demandas cadastradas (é preciso reatribuir ou excluir as demandas dele antes);
- um formulário de busca (com autocomplete por nome/e-mail já cadastrados + filtro por permissão) e paginação (10 por página).

## Identidade visual e busca/paginação

O layout usa uma identidade visual própria (`app/assets/stylesheets/application.css`), com gradiente verde-petróleo, tipografia Kanit/Open Sans e componentes reutilizáveis (navbar, cards, badges, paginação). As telas de Demandas e Acessos ganharam um formulário de busca (com `<datalist>` de autocomplete) e paginação simples via `Paginatable` (`app/controllers/concerns/paginatable.rb`) — implementada só com Active Record (`limit`/`offset`), sem depender de gem externa como Kaminari.

O filtro e a ordenação de `DemandasController#index` e `UsersController#index` são construídos internamente com [Ransack](https://github.com/activerecord-hackery/ransack), mas **a URL continua com o mesmo contrato simples de sempre** (`q`, `status`/`role`, `sort`, `direction`) — não expomos a sintaxe nativa do Ransack (`params[:q][:attr_predicate]`) para fora. `SORTABLE_COLUMNS`, em `DemandasController`/`UsersController`, continua sendo a whitelist de colunas ordenáveis (traduzindo cada uma para o nome de atributo esperado pelo Ransack, ex.: `"responsavel" => "user_name"`, a convenção do Ransack para "atributo `name` da associação `user`"), e `status`/`role` continuam validados contra o enum antes de chegar ao Ransack. Por segurança, o Ransack exige que cada model libere explicitamente o que pode ser buscado/ordenado — ver `ransackable_attributes`/`ransackable_associations` em `Demanda` e `User`.

**Seleção múltipla e ordenação em todas as colunas**: `status` (Demandas) e `role`/permissão (Acessos) agora aceitam mais de um valor ao mesmo tempo, via um `<select multiple>` — internamente vira `status_in`/`role_in` do Ransack (em vez de `status_eq`/`role_eq`). Nenhum valor selecionado equivale a "todos", igual antes. O campo de texto (`q`, título em Demandas / nome-ou-e-mail em Acessos) aceita mais de um termo separado por vírgula, combinados com OR via `_cont_any` — um único termo sem vírgula se comporta exatamente como antes (retrocompatível: os parâmetros antigos `status=x`/`role=x`, valor único, continuam funcionando — `Array()` normaliza os dois formatos). A tela de Acessos ganhou ordenação clicável em todas as colunas (Nome, E-mail, Permissão), igual já existia em Demandas — a lógica do cabeçalho clicável foi extraída pra `ApplicationHelper#sort_header`, reaproveitada pelas duas telas (`demanda_sort_header`/`user_sort_header`).

As páginas de listagem (Demandas, Acessos) não repetem o nome da seção como um heading gigante logo abaixo do menu — o item ativo na navbar já indica onde você está, e o título de cada página fica no `<title>` da aba do navegador (`content_for :page_title`); o `%h1` continua no HTML por acessibilidade, só que visualmente oculto (`visually-hidden`).

Os alertas (`flash`) são fecháveis, com um "×" no canto (`alert-dismissible` do Bootstrap), e também se fecham sozinhos depois de 40 segundos (`app/javascript/application.js`, ouvindo `turbo:load`) — o que vier primeiro, clique ou tempo.

## Acessibilidade

Uma barra fixa no topo de toda página (com ou sem login, incluindo a própria tela de login) oferece:

- **Tamanho da fonte** (`A−` / `A+` / `↺A`): aumenta ou diminui o texto de toda a aplicação em passos de 10% (entre 80% e 150%), com um botão para voltar ao padrão. A escolha fica salva no navegador (`localStorage`) e vale para as próximas visitas;
- **Alto contraste** (`◐`): alterna para um esquema de cores fundo preto / texto branco / destaque amarelo — a mesma convenção usada no modo de alto contraste nativo do Windows. A escolha também fica salva;
- **Libras** (`♿`): o [VLibras](https://www.gov.br/governodigital/pt-br/vlibras), widget oficial do governo federal (o mesmo padrão usado em sites gov.br, incluindo o da CGE-CE que inspirou a identidade visual deste app) para tradução do conteúdo em Língua Brasileira de Sinais;
- o mesmo botão `♿` leva também a `/acessibilidade`, uma página pública (não exige login) explicando cada um desses recursos.

A implementação de fonte/contraste é só JS (`app/javascript/application.js`, objeto `window.TkAccessibility`) manipulando o `<html>` (que sobrevive à troca de `<body>` nas navegações via Turbo Drive) — por isso não tem cobertura em RSpec, na mesma linha do que já vale para outras interações só-JS do projeto; a rota `/acessibilidade` em si (pública, responde 200 com ou sem login) está coberta em `spec/requests/pages_spec.rb`. A barra de busca com microfone que aparece em referências de sites gov.br não foi incluída aqui por não ter um caso de uso claro nesta aplicação (o app já tem busca por título/nome nas telas de Demandas e Acessos).

## Mensagens em pt-BR

O locale padrão da aplicação é `pt-BR` (ver `config/application.rb`), mas nem o Rails nem o Devise têm tradução embutida para esse locale — sem `config/locales/pt-BR.yml`, mensagens como a de "faça login para continuar" apareciam como `Translation missing`. Esse arquivo traduz as mensagens do Devise (login, logout, credenciais inválidas, recuperação de senha), as mensagens padrão de validação do Rails (`não pode ficar em branco`, `já está em uso` etc.), incluindo os nomes dos campos (`Título`, `E-mail`, `Permissão`...), e também `datetime.distance_in_words` (usado por `time_ago_in_words` em "Atividade recente" no painel inicial — sem essa tradução, o mesmo `Translation missing` apareceria ali). A regressão (mensagem sem login e credenciais inválidas) tem teste dedicado em `spec/requests/devise_i18n_spec.rb`.

## Devise + Turbo Drive

A tela de login usa Turbo Drive (gem `turbo-rails`), que exige que toda resposta **2xx** a um `POST` de formulário seja um redirect — senão lança `Error: Form responses must redirect to another location` no console do navegador e não faz nada (a tela trava sem nenhum feedback pro usuário, nem a mensagem de erro aparece).

Por padrão, o responder do Devise devolve `200 OK` quando um login falha (ele re-renderiza a tela de login com o erro, mas sem redirecionar) — o que é exatamente o caso que quebra o Turbo Drive. Desde a v5, o próprio Devise recomenda (no template do seu gerador) configurar:

```ruby
config.responder.error_status = :unprocessable_entity   # 422 em vez de 200
config.responder.redirect_status = :see_other            # 303 em vez de 302
```

com `422` o Turbo Drive passa a tratar a resposta como "renderizar no lugar" (igual já faz para erros de validação em formulários comuns), em vez de reclamar. Isso já está configurado em `config/initializers/devise.rb`; a regressão tem teste dedicado em `spec/requests/devise_turbo_spec.rb`.
