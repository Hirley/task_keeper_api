# Contexto para agentes

Rails 8.1 + PostgreSQL, com interface web (HAML) e API JSON versionada lado a lado. O `README.md` descreve o **produto**; este arquivo descreve como **trabalhar** nele. O `ROADMAP.md` é o backlog: cada item já traz problema, proposta e critério de aceite, e faz o papel de issue.

Leia isto antes de editar qualquer coisa. As armadilhas listadas aqui não são hipotéticas — todas já custaram um push extra, um CI vermelho ou uma correção de rumo.

## Idioma

Tudo em pt-BR: comentários, mensagens de commit, descrições de spec, textos de flash e de erro. Nomes de método e variável ficam em português quando são do domínio (`demanda`, `campos_serializados`, `validar_atribuicao_de_papel`) e em inglês quando são convenção do Rails ou do Devise (`user_params`, `set_user`, `must_change_password`). Não misture os dois dentro do mesmo método.

## Comentários explicam o porquê

`Style/Documentation` está desligado no `.rubocop.yml` de propósito: este projeto não documenta classes em RDoc, documenta **decisões**. Um comentário aqui responde "por que assim, e não do outro jeito", e costuma nomear a alternativa descartada.

Duas obrigações que vêm disso:

- ao mexer num trecho comentado, **atualize o comentário**. Um comentário que descreve o código anterior é pior que nenhum;
- ao tomar uma decisão não óbvia — validação de modelo em vez de strong params, `'unsafe-inline'` liberado num lugar e não noutro —, registre o motivo junto. Se você precisou pensar, quem vier depois também vai.

## Nada roda direto nesta máquina

Não há Ruby compatível instalado no Windows (existe um 3.2.4 em `C:\Ruby32-x64`; o projeto exige 4.0.6, então o Bundler recusa). **RSpec e RuboCop rodam em container.** Use a skill `verificar-local`, que sobe `ruby:4.0.6-slim` + `postgres:16-alpine` espelhando o `ci.yml` e devolve um ciclo de ~20 segundos.

Corolário: nunca afirme que um teste passou sem ter rodado. Se o container não estiver de pé e não der para subir, diga que o código foi revisado mas não executado — foi o que aconteceu nos primeiros commits da revisão de segurança, e vale dizer em voz alta, não omitir.

## Portões antes de abrir PR

Na ordem, todos dentro do container:

1. `bundle exec rubocop` — zero ofensas;
2. `bin/rails zeitwerk:check` — o CI roda isso separado do RSpec de propósito, porque erro de autoload não aparece no processo do RSpec;
3. `bundle exec rspec` — suíte inteira, não só o arquivo que você mexeu;
4. **navegador**, se você tocou em JS, CSS, HAML ou CSP (ver abaixo).

## O que os specs não cobrem

O `Gemfile` não tem driver Capybara/JS. Nada que dependa de JavaScript no navegador tem teste automatizado: barra de acessibilidade, tour guiado, dropdown de busca, widget do VLibras, e o CSP inteiro.

Se você mexeu nessas áreas, suba a app e verifique de verdade — console sem erros, elemento aparecendo, clique funcionando, **e o mesmo depois de uma navegação do Turbo Drive**. O CSP deste projeto foi corrigido duas vezes por causa de coisas que só o navegador mostrou, e nenhuma delas quebraria um spec.

## Armadilhas deste repositório

**`db/schema.rb` regenerado no container vem com ruído.** O Postgres 16 do container acrescenta `enable_extension "pg_catalog.plpgsql"` e reordena as opções da coluna `events`. Para migration que só mexe em dados, edite **apenas** a linha `define(version:)` à mão e descarte o resto.

**Git Bash converte caminho em argumento de `docker`.** `-w /app` vira `C:/Program Files/Git/app`. Prefixe os comandos com `MSYS_NO_PATHCONV=1`. Cuidado ao exportar essa variável para o shell inteiro: aí o `curl` do Git Bash também deixa de converter, e `-o /dev/null` falha com `curl: (23)` — parece erro da aplicação e não é.

**Script novo em `bin/` nasce sem bit de execução.** O sistema de arquivos do Windows não tem esse bit, então o Git registra `100644`. Um `docker build` daqui não percebe (o contexto vem do disco, onde tudo parece executável) e um checkout Linux respeita o índice — foi assim que `bin/jobs` derrubou o container do worker com `exit 126`, com a imagem de `main` quebrada por dois merges. Depois de criar um script em `bin/`, rode `git update-index --chmod=+x bin/<arquivo>` e confira com `git ls-files -s bin/`. O `chmod +x bin/*` do Dockerfile é rede de segurança da imagem, não do repositório.

**Cops que já morderam:**

- `RSpec/ContainExactly` — com array splatado (`contain_exactly(*lista)`) ele exige `match_array(lista)`;
- `Naming/PredicateMethod` — método que só retorna booleano precisa de `?`; separe o efeito colateral do valor de retorno em vez de renomear;
- `Layout/LineLength` — o limite é 130, não 120.

**`Api::V1::BaseController` herda de `ActionController::Base`, não de `ApplicationController`.** É deliberado (há uma exceção no `.rubocop.yml` explicando), mas significa que **todo `before_action` da web precisa ser incluído lá explicitamente**. Já foi a causa de a API inteira ficar fora do portão de senha provisória. Ao adicionar uma regra transversal, prefira um concern incluído nos dois — e sem implementação padrão, para que esquecer levante `NotImplementedError` em vez de passar em silêncio.

**Devise + Turbo Drive** exige `config.responder.error_status = :unprocessable_entity`; sem isso a tela de login trava sem feedback. Ver a seção correspondente no README.

**Nonce do CSP vive na sessão, não na requisição.** O Turbo troca o `<body>` sem criar documento novo, então continua valendo o CSP da primeira resposta. Nonce aleatório por requisição quebra a navegação. Não "melhore" isso sem ler o comentário no initializer.

## Git e PRs

- Branch a partir de `main`, nomeada `claude-<usuário>/<slug-curto>`.
- Commits em pt-BR, imperativo, com corpo explicando o **porquê** — mesma régua dos comentários. Trailer `Co-Authored-By` no fim.
- Um assunto por commit. Achados independentes podem ir no mesmo PR, mas em commits separados.
- Merge com `gh pr merge N --merge` (merge commit), que é o padrão do histórico. Não use squash.
- **PRs empilhados não são reapontados sozinhos** quando a base é mergeada, se a branch de base ainda existir. Rode `gh pr edit N --base main` antes de mergear, senão o merge cai na branch antiga.
- Descrição de PR não é changelog: explique a decisão, o que foi descartado e o que **não** foi verificado.

## Honestidade sobre o próprio trabalho

Este repositório passou por uma revisão de segurança em que vários achados foram reclassificados depois de investigados — um deles estava simplesmente errado na premissa, e só apareceu porque o histórico do Git foi conferido antes de escrever a correção. Verifique a premissa antes de consertar. E quando a verificação contrariar o que você já afirmou, corrija em voz alta.

**O primeiro login de um processo já quebrou por causa de rota preguiçosa.** `Devise.configure_warden!` só roda quando o RouteSet é finalizado; sem eager load isso acontecia dentro da primeira requisição, depois de o Warden já ter copiado uma config sem estratégia nenhuma — e um `POST /users/sign_in` com credenciais válidas respondia 422. Corrigido por um `after_initialize` no fim de `config/initializers/devise.rb`, com `spec/devise_warden_boot_spec.rb` guardando a invariante. Se algum dia a suíte falhar num login que deveria funcionar, comece por aí: o sintoma aparece e some conforme a ordem aleatória do RSpec, o que faz parecer culpa do PR da vez.
