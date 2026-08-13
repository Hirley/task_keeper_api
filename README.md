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

## Tela web de demandas

Além da API, há uma tela em `/demandas` (menu "Demandas" no topo) para uso pelos usuários autenticados:

- ambos os papéis veem o botão **Nova demanda** e podem cadastrar;
- apenas o líder vê a coluna **Ações**, com os botões **Editar** e **Excluir** em cada linha;
- se um executor tentar acessar `/demandas/:id/edit` diretamente, é redirecionado com aviso de permissão negada;
- o botão **Excluir** pede confirmação (`data-turbo-confirm`, via Turbo) antes de enviar o form de exclusão.

## Nota sobre este scaffold

Este projeto foi gerado por escrita direta de todos os arquivos (models, controllers, views, migrations e specs), e não via `rails new`/`bundle install`, porque o ambiente onde foi gerado não tem acesso ao rubygems.org nem ao Ruby 4.0.6. Ou seja, o código **não foi executado nem testado automaticamente** neste ambiente — rode `bundle install && bin/rails db:prepare && bundle exec rspec` localmente para validar antes de usar em produção.
