# task_keeper_api

API REST em Ruby on Rails para criar, organizar e acompanhar demandas diárias, com controle de acesso via CanCanCan, interface web em HAML + Bootstrap e testes automatizados em RSpec.

## Stack

- Ruby 4.0.6 · Ruby on Rails 8.1
- Devise (autenticação) + CanCanCan (autorização)
- HAML + Bootstrap (interface web mínima)
- Ransack (mecanismo interno de filtro/ordenação — ver "Identidade visual e busca/paginação")
- RSpec + FactoryBot + Shoulda Matchers (testes)
- PostgreSQL
- Docker (opcional — ver seção "Docker")

## Regras de negócio

- Existem dois papéis de usuário: **líder** e **executor**.
- Ambos os papéis podem cadastrar novas demandas.
- Apenas o líder pode editar ou excluir uma demanda já existente.
- O cadastro de demanda traz a data atual por padrão, mas permite escolher outra; após criada, só o líder pode alterar essa data.
- Apenas o líder pode cadastrar, alterar a permissão (papel) e excluir usuários (não há autocadastro).
- Um líder não pode excluir a própria conta, nem excluir um usuário que já tenha demandas cadastradas.

## Setup local

Requer um PostgreSQL rodando (localmente instalado, ou via `docker compose up db` — ver seção "Docker"). Por padrão a aplicação espera `localhost:5432`, usuário/senha `postgres`/`postgres` (ver `config/database.yml` e `.env.example`); ajuste `DB_HOST`/`DB_USERNAME`/`DB_PASSWORD`/`DB_NAME` (ou `DATABASE_URL`) se o seu Postgres local usa outras credenciais.

```bash
cp .env.example .env   # ajuste as credenciais do Postgres se precisar
bundle install
bin/rails db:prepare
bin/rails db:seed   # cria um usuário líder e um executor de exemplo
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
| líder    | lider@task-keeper.local        | senha123456  |
| executor | executor@task-keeper.local     | senha123456  |

## Migração de SQLite para PostgreSQL

O projeto usava SQLite (arquivo local em `storage/*.sqlite3`) e passou a usar PostgreSQL — `config/database.yml` agora lê a conexão de variáveis de ambiente (ver `.env.example`) em vez de apontar pra um arquivo.

O que foi conferido de fato (este ambiente tem um PostgreSQL local disponível, então deu pra validar sem depender só de leitura de código):

- o DDL equivalente ao `db/schema.rb` (tipos de coluna, índices, a foreign key de `demandas.user_id`) foi criado manualmente num Postgres real sem erro;
- a migration `AddDataToDemandas` usa `DATE('now')` num `UPDATE` — sintaxe que também funciona no PostgreSQL (não é exclusiva do SQLite, então essa migration não precisou mudar);
- a consulta com SQL cru do painel inicial (`ORDER BY (status = 2) ASC, data ASC`, em `DashboardController#index`) também funciona no PostgreSQL;
- o predicado `_cont` do Ransack (busca por título/nome/e-mail) usa o método `matches` do Arel, não `LIKE` cru — no PostgreSQL isso vira `ILIKE` automaticamente (case-insensitive, igual já era no SQLite); não deveria haver regressão de comportamento na busca.
- `config/database.yml` foi renderizado (ERB) com Ruby puro em 3 cenários (sem `DATABASE_URL`, com `DATABASE_URL` simulando Railway, e com as variáveis do `docker-compose.yml`) para confirmar que a URL de conexão monta certo em cada caso.

O que **não** pôde ser verificado: rodar a aplicação Rails de verdade contra esse Postgres (sem acesso ao rubygems.org/à versão de Ruby do projeto neste ambiente — mesma limitação já documentada nas seções de CI e Docker) e `bundle exec rspec` na íntegra.

⚠️ **Bloqueio conhecido**: `pg` foi adicionado ao `Gemfile` no lugar de `sqlite3`, mas o `Gemfile.lock` **ainda não foi regenerado** — ele continua resolvendo `sqlite3`, não `pg` (este ambiente não tem a versão de Ruby do projeto disponível para gerar um lockfile válido, então essa correção precisa vir de fora). Isso afeta principalmente fluxos que exigem o lockfile já alinhado ao `Gemfile` antes de rodar — `bundle install` local (a linha "Depois de puxar mudanças no `Gemfile`, rode `bundle install` de novo" na seção "Setup local" resolve isso automaticamente, já que fora do modo `--deployment` o Bundler re-resolve e atualiza o lockfile sozinho) e qualquer futuro CI em modo frozen. **Não bloqueia o Docker**: o `Dockerfile` já roda `bundle lock --add-platform` (não-frozen) antes do `bundle install --deployment` (ver seção "Docker"), o que resolve `pg` e atualiza o lockfile dentro da própria imagem antes do passo que exige alinhamento — confirmado com um build real que chegou a instalar as gems (inclusive `pg`) sem esse erro, embora ainda seja recomendável commitar o `Gemfile.lock` já corrigido assim que possível, em vez de depender desse auto-ajuste a cada build.

## Docker

O `Dockerfile` builda uma imagem de produção em 2 etapas (build → final): a etapa final não carrega compilador nem código-fonte de gems, só o necessário para rodar a aplicação — Puma servindo direto (sem Thruster/Kamal, que não fazem parte do Gemfile deste projeto).

```bash
cp .env.example .env   # preencha SECRET_KEY_BASE (obrigatória — ver .env.example)
docker compose up --build
```

Isso sobe a imagem de produção **e** um serviço `db` (PostgreSQL) localmente, na porta `3000`, com os dados do banco persistidos num volume nomeado (sobrevivem a `docker compose down`, mas não a `docker compose down -v`). Não é um ambiente de desenvolvimento com hot-reload — para isso, continue usando `bundle install && bin/rails server` (apontando pro serviço `db` ou pra um Postgres local), como na seção anterior.

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

⚠️ **Não totalmente verificado**: este ambiente não tem acesso ao registro do Docker Hub, então não foi possível rodar `docker build`/`docker compose up` de verdade aqui — só validação estática (sintaxe do `docker-compose.yml`, `docker compose config`, `bash -n` no entrypoint). O build já foi tentado de verdade fora deste ambiente (Docker Desktop), o que confirmou a versão `ruby:4.0.6-slim` da imagem-base e a necessidade do ajuste de plataforma acima — e também revelou um bug real, já corrigido: o `COPY . .` rodava depois do `bundle lock --add-platform`, sobrescrevendo silenciosamente o `Gemfile.lock` já corrigido dentro da imagem com a versão original do host, o que derrubava o `bootsnap precompile app/ lib/` logo em seguida (`bundle exec` revalida a plataforma a cada chamada). O Dockerfile atual já copia o projeto inteiro antes de mexer no `Gemfile.lock`, então isso não deve mais acontecer — mas como este ambiente não pode confirmar um build completo, ainda vale rodar `docker compose build --progress=plain web` de novo (ou `docker compose up --build`) antes de considerar o Dockerfile plenamente validado.

## Integração contínua

Ainda não há um workflow de GitHub Actions configurado neste repositório — `bundle exec rubocop` e `bundle exec rspec` são, por enquanto, rodados manualmente (localmente ou antes de cada merge). `.ruby-version` e `.rubocop.yml` já estão no repositório, prontos para quando um workflow de CI for adicionado.

## Cobertura de testes

A suíte RSpec cobre:

- **Models**: `User` e `Demanda` (`spec/models`), incluindo a validação do `telegram_chat_id` e o reset de `atraso_notificado_em`;
- **Política de autorização**: `Ability` (`spec/models/ability_spec.rb`), validando cada combinação de papel × ação para `Demanda` e `User`;
- **Serviços** (`spec/services`): `TelegramNotifier` — mensagem, envio e os casos de "não enviar" (sem token, sem chat_id, erro de rede), usando um dublê de transporte HTTP injetado no serviço (sem depender de gem de mock de rede); `Users::Destroy` — a regra de exclusão de usuário (exclusão da própria conta/demandas vinculadas), testada uma única vez e reaproveitada pela tela web e pela API;
- **Tarefa agendada**: a rake task `demandas:notificar_atrasos` (`spec/tasks`) — idempotência, filtro por status/data/chat_id cadastrado;
- **API** (`spec/requests/api/v1`): `demandas` e `users`;
- **Telas web** (`spec/requests`): `demandas` (menu Demandas), `users` (menu Acessos), `dashboard` (painel inicial/Início) e a página pública `/acessibilidade`;
- **Traduções pt-BR** (`spec/requests/devise_i18n_spec.rb`): regressão para a mensagem `Translation missing` do Devise (ver seção "Mensagens em pt-BR").

Cenários validados explicitamente:

- um `executor` consegue criar uma demanda (via tela ou API), mas recebe `403`/é redirecionado ao tentar atualizar ou excluir;
- um `líder` consegue criar, atualizar e excluir demandas;
- apenas um `líder` consegue listar/criar/excluir usuários, tanto pela tela `/users` quanto por `/api/v1/users`;
- um `líder` não consegue excluir a própria conta, nem um usuário com demandas vinculadas;
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
| POST   | `/api/v1/demandas`        | líder ou executor              |
| PATCH  | `/api/v1/demandas/:id`    | apenas líder                   |
| DELETE | `/api/v1/demandas/:id`    | apenas líder                   |
| GET    | `/api/v1/users`           | apenas líder                   |
| GET    | `/api/v1/users/:id`       | apenas líder                   |
| POST   | `/api/v1/users`           | apenas líder                   |
| DELETE | `/api/v1/users/:id`       | apenas líder                   |

Toda ação de escrita (`POST`/`PATCH`/`DELETE`) exige o header `Content-Type: application/json` — uma requisição sem esse header recebe `415 Unsupported Media Type`. Isso não é um capricho de formato: essa API autentica por sessão (cookie do Devise) e tem o token CSRF desativado (`Api::V1::BaseController`), então exigir `application/json` é o que impede um `<form>` HTML comum de outro site de forjar uma requisição usando a sessão já autenticada do usuário — um formulário nunca consegue definir esse Content-Type, só `application/x-www-form-urlencoded`, `multipart/form-data` ou `text/plain`.

## Painel inicial (dashboard)

A home (`/`, menu "Início") é um painel com uma visão geral das demandas, pensado para responder duas perguntas diferentes: "o que precisa da minha atenção agora?" e "como está a equipe?" — nessa ordem de prioridade:

- KPIs no topo: total de demandas e quantas estão em cada status;
- **Minhas demandas**: as demandas do próprio usuário logado, ordenadas por urgência (atrasada primeiro, depois o que vence antes); cada uma tem um badge de prazo (`Atrasada há N dias`, `Vence hoje`, `Vence amanhã`, `Vence em N dias`) — um canal separado do badge de status, porque "em que fase está" e "está no prazo?" são informações diferentes;
- **Atividade recente**: últimas demandas criadas por toda a equipe;
- **Distribuição por status**: uma única barra empilhada (não faz sentido um gráfico maior para 3 fatias) com a proporção pendente/em andamento/concluída;
- **Prazos**: quantas demandas (de toda a equipe) estão atrasadas, vencem hoje, ou vencem nos próximos `DashboardController::PRAZO_PROXIMO_DIAS` dias (3 por padrão);
- **Carga por responsável**: quantas demandas abertas (não concluídas) cada pessoa tem, da maior carga para a menor — visível para os dois papéis, já que qualquer usuário autenticado já enxerga todas as demandas na listagem;
- **Equipe** (só para o líder): contagem de líderes/executores, com atalho para `/users`.

Todos os dados vêm do banco (nada é fixo/mockado) e respeitam a mesma autorização já usada na listagem de demandas (`Demanda.accessible_by(current_ability)`).

## Notificação de atraso via Telegram

Quando uma demanda de um executor fica atrasada (data no passado e ainda não concluída — o mesmo critério já usado no badge "Atrasada há N dias" do painel inicial), o app pode avisar o responsável por mensagem no Telegram. É opt-in por usuário e não depende de nenhum serviço externo pago.

**Configuração:**

1. Crie um bot conversando com o [@BotFather](https://t.me/BotFather) no Telegram (`/newbot`) e copie o token gerado.
2. Configure a variável de ambiente `TELEGRAM_BOT_TOKEN` com esse token (no Railway: aba **Variables** do serviço).
3. Cada usuário que quiser receber avisos descobre o próprio `chat_id` conversando com o bot [@WhatChatIDBot](https://t.me/WhatChatIDBot) ou [@ShowJsonBot](https://t.me/ShowJsonBot) no Telegram (`/start` e o bot já responde com o ID numérico).
4. O líder cadastra esse `chat_id` no campo **Chat ID do Telegram** ao criar ou editar o usuário em `/users` — o próprio formulário tem um ícone ⓘ ao lado do campo com esse mesmo passo a passo, em forma de tooltip.

**Como funciona:**

- `TelegramNotifier` (`app/services/telegram_notifier.rb`) monta a mensagem e chama a API do Telegram (`sendMessage`) via `Net::HTTP` puro, sem depender de nenhuma gem adicional.
- A mensagem é empática e objetiva: cita o título da demanda e há quantos dias está atrasada, sem tom de cobrança, e diz o que fazer a seguir (atualizar o status, ou avisar o líder se precisar de mais tempo/ajuda).
- Como "ficar atrasada" é um estado que muda com o tempo (não com uma ação do usuário), o envio não acontece automaticamente na aplicação — é a tarefa `bin/rails demandas:notificar_atrasos` (`lib/tasks/telegram_notifications.rake`) que precisa rodar periodicamente (ex.: 1x ao dia). No Railway, isso é feito criando um segundo serviço do tipo **Cron Job** no mesmo projeto, rodando esse comando.
- Cada atraso é notificado **uma única vez** (campo `Demanda#atraso_notificado_em`) — se a demanda deixar de estar atrasada (data adiada ou marcada como concluída) e depois atrasar de novo, um novo aviso é enviado.
- Sem `TELEGRAM_BOT_TOKEN` configurado, ou sem `telegram_chat_id` no usuário, a notificação é simplesmente pulada (não é um erro).

## Tela web de demandas

Além da API, há uma tela em `/demandas` (menu "Demandas" no topo) para uso pelos usuários autenticados:

- ambos os papéis veem o botão **Nova demanda** e podem cadastrar;
- apenas o líder vê a coluna **Ações**, com os botões **Editar** e **Excluir** em cada linha;
- se um executor tentar acessar `/demandas/:id/edit` diretamente, é redirecionado com aviso de permissão negada;
- o botão **Excluir** pede confirmação (`data-turbo-confirm`, via Turbo) antes de enviar o form de exclusão;
- um formulário de busca (com autocomplete por título já cadastrado + filtro por status) e paginação (10 por página);
- as colunas **Título**, **Data**, **Status**, **Responsável** e **Criada em** são clicáveis e ordenam a listagem (clicar de novo inverte a direção); o filtro de busca preserva a ordenação escolhida;
- o cadastro tem um campo **Data**, preenchido por padrão com a data atual, mas que pode ser alterado para outra data no momento da criação; depois que a demanda já existe, só o líder pode alterar essa data (mesma regra de edição das demais informações da demanda).

## Tela web de Acessos

Há também uma tela em `/users` (menu "Acessos" no topo, visível apenas ao líder) para o líder cadastrar novos usuários e alterar a permissão (papel líder/executor) de usuários já existentes:

- apenas o líder vê o menu "Acessos" e consegue acessar `/users`; um executor que tentar acessar diretamente é redirecionado com aviso de permissão negada;
- o cadastro de um novo usuário exige nome, e-mail, senha e a permissão (líder ou executor) — não há autocadastro;
- a edição permite alterar nome, e-mail e a permissão de um usuário existente (a troca de senha continua pelo fluxo de "esqueci minha senha" do Devise);
- o líder também pode **excluir** outros usuários (com confirmação via Turbo). Duas travas de segurança: o líder não pode excluir a própria conta, e não é possível excluir um usuário que já tenha demandas cadastradas (é preciso reatribuir ou excluir as demandas dele antes);
- um formulário de busca (com autocomplete por nome/e-mail já cadastrados + filtro por permissão) e paginação (10 por página).

## Identidade visual e busca/paginação

O layout usa uma identidade visual própria (`app/assets/stylesheets/application.css`), com gradiente verde-petróleo, tipografia Kanit/Open Sans e componentes reutilizáveis (navbar, cards, badges, paginação). As telas de Demandas e Acessos ganharam um formulário de busca (com `<datalist>` de autocomplete) e paginação simples via `Paginatable` (`app/controllers/concerns/paginatable.rb`) — implementada só com Active Record (`limit`/`offset`), sem depender de gem externa como Kaminari.

O filtro e a ordenação de `DemandasController#index` e `UsersController#index` são construídos internamente com [Ransack](https://github.com/activerecord-hackery/ransack), mas **a URL continua com o mesmo contrato simples de sempre** (`q`, `status`/`role`, `sort`, `direction`) — não expomos a sintaxe nativa do Ransack (`params[:q][:attr_predicate]`) para fora. `SORTABLE_COLUMNS`, em `DemandasController`, continua sendo a whitelist de colunas ordenáveis (traduzindo cada uma para o nome de atributo esperado pelo Ransack, ex.: `"responsavel" => "user_name"`, a convenção do Ransack para "atributo `name` da associação `user`"), e `status`/`role` continuam validados contra o enum antes de chegar ao Ransack. Por segurança, o Ransack exige que cada model libere explicitamente o que pode ser buscado/ordenado — ver `ransackable_attributes`/`ransackable_associations` em `Demanda` e `User`.

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
