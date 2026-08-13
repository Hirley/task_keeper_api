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
- Apenas o líder pode cadastrar novos usuários (não há autocadastro).

## Cobertura de testes

A suíte RSpec cobre models (`User`, `Demanda`), a política de autorização (`Ability`) e os endpoints da API (`spec/requests/api/v1`), validando explicitamente que:

- um `executor` consegue criar uma demanda mas recebe `403` ao tentar atualizar ou excluir;
- um `líder` consegue criar, atualizar e excluir demandas;
- apenas um `líder` consegue listar/criar usuários via `/api/v1/users`.

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
- o botão **Excluir** pede confirmação (`data-turbo-confirm`, via Turbo) antes de enviar o form de exclusão.

## Tela web de Acessos

Há também uma tela em `/users` (menu "Acessos" no topo, visível apenas ao líder) para o líder cadastrar novos usuários e alterar a permissão (papel líder/executor) de usuários já existentes:

- apenas o líder vê o menu "Acessos" e consegue acessar `/users`; um executor que tentar acessar diretamente é redirecionado com aviso de permissão negada;
- o cadastro de um novo usuário exige nome, e-mail, senha e a permissão (líder ou executor) — não há autocadastro;
- a edição permite alterar nome, e-mail e a permissão de um usuário existente (a troca de senha continua pelo fluxo de "esqueci minha senha" do Devise);
- o líder também pode **excluir** outros usuários (com confirmação via Turbo). Duas travas de segurança: o líder não pode excluir a própria conta, e não é possível excluir um usuário que já tenha demandas cadastradas (é preciso reatribuir ou excluir as demandas dele antes).

## Nota sobre validação

O scaffold inicial (models, controllers, views, migrations e specs) foi escrito diretamente em um ambiente sem acesso ao rubygems.org/Ruby 4.0.6, então não pôde ser testado automaticamente ali — mas já foi validado localmente (`bundle install`, migrations e `bundle exec rspec`) e mesclado à `main`. PRs subsequentes devem seguir o mesmo processo: rodar `bundle install && bin/rails db:prepare && bundle exec rspec` localmente antes do merge.
