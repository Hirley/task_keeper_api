# task_keeper_api

API REST em Ruby on Rails para criar, organizar e acompanhar demandas diárias, com controle de acesso via CanCanCan, interface web em HAML + Bootstrap e testes automatizados em RSpec.

## Stack

- Ruby 4.0.6 · Ruby on Rails 8.1
- Devise (autenticação) + CanCanCan (autorização)
- HAML + Bootstrap (interface web mínima)
- RSpec + FactoryBot + Shoulda Matchers (testes)
- SQLite

## Regras de negócio

- Existem dois papéis de usuário: **líder** e **executor**.
- Ambos os papéis podem cadastrar novas demandas.
- Apenas o líder pode editar ou excluir uma demanda já existente.
- Apenas o líder pode cadastrar, alterar a permissão (papel) e excluir usuários (não há autocadastro).
- Um líder não pode excluir a própria conta, nem excluir um usuário que já tenha demandas cadastradas.

## Cobertura de testes

A suíte RSpec cobre:

- **Models**: `User` e `Demanda` (`spec/models`);
- **Política de autorização**: `Ability` (`spec/models/ability_spec.rb`), validando cada combinação de papel × ação para `Demanda` e `User`;
- **API** (`spec/requests/api/v1`): `demandas` e `users`;
- **Telas web** (`spec/requests`): `demandas` (menu Demandas) e `users` (menu Acessos).

Cenários validados explicitamente:

- um `executor` consegue criar uma demanda (via tela ou API), mas recebe `403`/é redirecionado ao tentar atualizar ou excluir;
- um `líder` consegue criar, atualizar e excluir demandas;
- apenas um `líder` consegue listar/criar/excluir usuários, tanto pela tela `/users` quanto por `/api/v1/users`;
- um `líder` não consegue excluir a própria conta, nem um usuário com demandas vinculadas;
- o botão "Excluir" (demandas e usuários) carrega o Turbo e mostra o alerta de confirmação antes de enviar o form.

## Setup local

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed   # cria um usuário líder e um executor de exemplo
bin/rails server
```

Rodar a suíte de testes:

```bash
bundle exec rspec
```

Usuários de exemplo criados pelo `db:seed`:

| Papel    | E-mail                        | Senha        |
|----------|--------------------------------|--------------|
| líder    | lider@task-keeper.local        | senha123456  |
| executor | executor@task-keeper.local     | senha123456  |

## Endpoints principais

| Verbo  | Rota                    | Quem pode acessar          |
|--------|--------------------------|-----------------------------|
| GET    | `/api/v1/demandas`       | qualquer usuário autenticado |
| POST   | `/api/v1/demandas`       | líder ou executor            |
| PATCH  | `/api/v1/demandas/:id`   | apenas líder                 |
| DELETE | `/api/v1/demandas/:id`   | apenas líder                 |
| GET    | `/api/v1/users`          | apenas líder                 |
| POST   | `/api/v1/users`          | apenas líder                 |
| DELETE | `/api/v1/users/:id`      | apenas líder                 |

## Tela web de demandas

Além da API, há uma tela em `/demandas` (menu "Demandas" no topo) para uso pelos usuários autenticados:

- ambos os papéis veem o botão **Nova demanda** e podem cadastrar;
- apenas o líder vê a coluna **Ações**, com os botões **Editar** e **Excluir** em cada linha;
- se um executor tentar acessar `/demandas/:id/edit` diretamente, é redirecionado com aviso de permissão negada;
- o botão **Excluir** pede confirmação (`data-turbo-confirm`, via Turbo) antes de enviar o form de exclusão;
- um formulário de busca (com autocomplete por título já cadastrado + filtro por status) e paginação (10 por página).

## Tela web de Acessos

Há também uma tela em `/users` (menu "Acessos" no topo, visível apenas ao líder) para o líder cadastrar novos usuários e alterar a permissão (papel líder/executor) de usuários já existentes:

- apenas o líder vê o menu "Acessos" e consegue acessar `/users`; um executor que tentar acessar diretamente é redirecionado com aviso de permissão negada;
- o cadastro de um novo usuário exige nome, e-mail, senha e a permissão (líder ou executor) — não há autocadastro;
- a edição permite alterar nome, e-mail e a permissão de um usuário existente (a troca de senha continua pelo fluxo de "esqueci minha senha" do Devise);
- o líder também pode **excluir** outros usuários (com confirmação via Turbo). Duas travas de segurança: o líder não pode excluir a própria conta, e não é possível excluir um usuário que já tenha demandas cadastradas (é preciso reatribuir ou excluir as demandas dele antes);
- um formulário de busca (com autocomplete por nome/e-mail já cadastrados + filtro por permissão) e paginação (10 por página).

## Identidade visual e busca/paginação

O layout usa uma identidade visual própria (`app/assets/stylesheets/application.css`), com gradiente verde-petróleo, tipografia Kanit/Open Sans e componentes reutilizáveis (navbar, cards, badges, paginação). As telas de Demandas e Acessos ganharam um formulário de busca (com `<datalist>` de autocomplete) e paginação simples via `Paginatable` (`app/controllers/concerns/paginatable.rb`) — implementada só com Active Record (`limit`/`offset`), sem depender de gem externa como Kaminari.

## Mensagens em pt-BR

O locale padrão da aplicação é `pt-BR` (ver `config/application.rb`), mas nem o Rails nem o Devise têm tradução embutida para esse locale — sem `config/locales/pt-BR.yml`, mensagens como a de "faça login para continuar" apareciam como `Translation missing`. Esse arquivo traduz as mensagens do Devise (login, logout, credenciais inválidas, recuperação de senha) e as mensagens padrão de validação do Rails (`não pode ficar em branco`, `já está em uso` etc.), incluindo os nomes dos campos (`Título`, `E-mail`, `Permissão`...).

## Nota sobre validação

O scaffold inicial (models, controllers, views, migrations e specs) foi escrito diretamente em um ambiente sem acesso ao rubygems.org/Ruby 4.0.6, então não pôde ser testado automaticamente ali — mas já foi validado localmente (`bundle install`, migrations e `bundle exec rspec`) e mesclado à `main`. PRs subsequentes devem seguir o mesmo processo: rodar `bundle install && bin/rails db:prepare && bundle exec rspec` localmente antes do merge.
