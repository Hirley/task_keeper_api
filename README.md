# task_keeper_api

API REST em Ruby on Rails para criar, organizar e acompanhar demandas diárias, com controle de acesso via CanCanCan, interface web em HAML + Bootstrap e testes automatizados em RSpec.

## Stack

- Ruby 4.0.6 · Ruby on Rails 8.1
- Devise (autenticação) + CanCanCan (autorização)
- HAML + Bootstrap (interface web mínima)
- Ransack (mecanismo interno de filtro/ordenação — ver "Identidade visual e busca/paginação")
- RSpec + FactoryBot + Shoulda Matchers (testes)
- SQLite
- Docker (opcional — ver seção "Docker")

## Regras de negócio

- Existem dois papéis de usuário: **líder** e **executor**.
- Ambos os papéis podem cadastrar novas demandas.
- Apenas o líder pode editar ou excluir uma demanda já existente.
- O cadastro de demanda traz a data atual por padrão, mas permite escolher outra; após criada, só o líder pode alterar essa data.
- Apenas o líder pode cadastrar, alterar a permissão (papel) e excluir usuários (não há autocadastro).
- Um líder não pode excluir a própria conta, nem excluir um usuário que já tenha demandas cadastradas.

## Setup local

```bash
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

## Docker

O `Dockerfile` builda uma imagem de produção em 2 etapas (build → final): a etapa final não carrega compilador nem código-fonte de gems, só o necessário para rodar a aplicação — Puma servindo direto (sem Thruster/Kamal, que não fazem parte do Gemfile deste projeto).

```bash
cp .env.example .env   # preencha SECRET_KEY_BASE (obrigatória — ver .env.example)
docker compose up --build
```

Isso sobe a mesma imagem de produção localmente, na porta `3000`, com o banco SQLite persistido num volume nomeado (sobrevive a `docker compose down`, mas não a `docker compose down -v`). Não é um ambiente de desenvolvimento com hot-reload — para isso, continue usando `bundle install && bin/rails server`, como na seção anterior.

Sem `docker compose`, buildar e rodar manualmente:

```bash
docker build -t task_keeper_api .
docker run -p 3000:3000 -e SECRET_KEY_BASE=$(bin/rails secret) -v tk_storage:/rails/storage task_keeper_api
```

`bin/docker-entrypoint` roda `bin/rails db:prepare` (idempotente) toda vez que o container sobe, antes de iniciar o Puma — então o banco é criado/migrado automaticamente, sem passo manual.

Este projeto não tem `config/master.key`/`config/credentials.yml.enc`, então `SECRET_KEY_BASE` (variável de ambiente) é obrigatória em produção — sem ela, o container não sobe. As demais variáveis (`TELEGRAM_BOT_TOKEN`, `APP_HOST`, `RAILS_MAX_THREADS`) são opcionais; ver `.env.example` para a lista completa e o que cada uma faz.

⚠️ **Não verificado**: este ambiente não tem acesso ao registro do Docker Hub, então não foi possível rodar `docker build`/`docker compose up` de verdade aqui — só a validação estática que deu para fazer (sintaxe do `docker-compose.yml`, `docker compose config`, `bash -n` no entrypoint). Rode localmente assim que puder e cole aqui qualquer erro para eu corrigir. O ponto de maior risco: o `Gemfile` fixa `ruby "4.0.6"` (ver "Stack"), uma versão à frente do Ruby real disponível publicamente no momento em que isto foi escrito — se o `FROM ruby:4.0.6-slim` do `Dockerfile` falhar com "pull access denied"/"manifest unknown", builde apontando pra sua versão real, ex. `docker build --build-arg RUBY_VERSION=3.3.5 .` (ou `RUBY_VERSION=3.3.5` no `.env` ao usar o `docker compose`).

## Integração contínua

Ainda não há um workflow de GitHub Actions configurado neste repositório — `bundle exec rubocop` e `bundle exec rspec` são, por enquanto, rodados manualmente (localmente ou antes de cada merge). `.ruby-version` e `.rubocop.yml` já estão no repositório, prontos para quando um workflow de CI for adicionado.

## Cobertura de testes

A suíte RSpec cobre:

- **Models**: `User` e `Demanda` (`spec/models`), incluindo a validação do `telegram_chat_id` e o reset de `atraso_notificado_em`;
- **Política de autorização**: `Ability` (`spec/models/ability_spec.rb`), validando cada combinação de papel × ação para `Demanda` e `User`;
- **Serviços** (`spec/services`): `TelegramNotifier` — mensagem, envio e os casos de "não enviar" (sem token, sem chat_id, erro de rede), usando um dublê de transporte HTTP injetado no serviço (sem depender de gem de mock de rede); `Users::Destroy` — a regra de exclusão de usuário (exclusão da própria conta/demandas vinculadas), testada uma única vez e reaproveitada pela tela web e pela API;
- **Tarefa agendada**: a rake task `demandas:notificar_atrasos` (`spec/tasks`) — idempotência, filtro por status/data/chat_id cadastrado;
- **API** (`spec/requests/api/v1`): `demandas` e `users`;
- **Telas web** (`spec/requests`): `demandas` (menu Demandas), `users` (menu Acessos), `dashboard` (painel inicial/Início) e a página pública `/acessibilidade`.

Cenários validados explicitamente:

- um `executor` consegue criar uma demanda (via tela ou API), mas recebe `403`/é redirecionado ao tentar atualizar ou excluir;
- um `líder` consegue criar, atualizar e excluir demandas;
- apenas um `líder` consegue listar/criar/excluir usuários, tanto pela tela `/users` quanto por `/api/v1/users`;
- um `líder` não consegue excluir a própria conta, nem um usuário com demandas vinculadas;
- o botão "Excluir" (demandas e usuários) carrega o Turbo e mostra o alerta de confirmação antes de enviar o form;
- uma demanda atrasada é notificada uma única vez no Telegram, e um novo aviso só é enviado se ela atrasar de novo depois de deixar de estar atrasada;
- a API rejeita com `415` qualquer `POST`/`PATCH`/`DELETE` sem `Content-Type: application/json` (proteção contra CSRF — ver seção "Endpoints principais"), sem afetar `GET`.

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

O locale padrão da aplicação é `pt-BR` (ver `config/application.rb`), mas nem o Rails nem o Devise têm tradução embutida para esse locale — sem `config/locales/pt-BR.yml`, mensagens como a de "faça login para continuar" apareciam como `Translation missing`. Esse arquivo traduz as mensagens do Devise (login, logout, credenciais inválidas, recuperação de senha), as mensagens padrão de validação do Rails (`não pode ficar em branco`, `já está em uso` etc.), incluindo os nomes dos campos (`Título`, `E-mail`, `Permissão`...), e também `datetime.distance_in_words` (usado por `time_ago_in_words` em "Atividade recente" no painel inicial — sem essa tradução, o mesmo `Translation missing` apareceria ali).
