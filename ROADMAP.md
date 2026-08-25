# Roadmap

Melhorias propostas mas ainda não implementadas. Cada item documenta o problema, a proposta e o critério de aceite — quando alguém (humano ou IA) for implementar, esse contexto substitui uma issue separada.

## Dashboard: reduzir redundância entre KPIs e "Distribuição por status"

**Status:** v1 implementada (card escondido abaixo de `lg`, ver `app/views/dashboard/index.html.haml`). A iteração futura descrita abaixo continua em aberto.

**Problema:** no painel inicial (`app/views/dashboard/index.html.haml`), a mesma contagem por status aparece três vezes:

1. Os 4 cards de KPI no topo (`Pendentes: 1`, `Em andamento: 1`, `Concluídas: 0`) — cada um já com o valor absoluto **e** o percentual do total;
2. A barra empilhada + legenda do card "Distribuição por status" (mesmos 3 valores, mesmas 3 cores);

Em telas menores (`< lg`, ver `.col-lg-4` em `app/views/dashboard/index.html.haml:103`), a coluna direita empilha embaixo de "Minhas demandas"/"Atividade recente", então esse card repetido custa uma rolagem inteira de tela só pra chegar em "Prazos" e "Carga por responsável", que trazem informação nova.

**Proposta:**

1. Esconder o card "Distribuição por status" abaixo do breakpoint `lg` (`d-none d-lg-block` ou equivalente no card, `app/views/dashboard/index.html.haml:104`) — os KPIs do topo já cobrem a mesma informação nesses tamanhos de tela, e o card fica só nos tamanhos maiores, onde a coluna lateral tem espaço de sobra e a barra funciona como um resumo visual rápido sem precisar re-ler o topo.
2. Como consequência direta (sem precisar reordenar nada), em telas pequenas/médias "Prazos" e "Carga por responsável" sobem uma posição na coluna, reduzindo a rolagem até informação que não está duplicada em outro lugar da tela.

**Iteração futura (escopo maior, item separado):** usar o espaço liberado ativamente, não só reduzir rolagem — por exemplo, listar as 2-3 demandas mais urgentes por nome dentro do card "Prazos" (hoje só mostra contagem), ou aumentar o limite de "Atividade recente" (`DashboardController#index`, hoje `.limit(5)`) quando a barra não estiver visível. Vale medir se a v1 (esconder a barra) já resolve a percepção de redundância antes de investir nisso.

**Critério de aceite:**

- Abaixo do breakpoint `lg`, o card "Distribuição por status" não aparece.
- A partir de `lg`, comportamento igual ao atual.
- Specs de `spec/requests/dashboard_spec.rb` continuam passando; adicionar um teste que confirme a classe responsiva no card (ou a ausência do texto renderizado, se o teste simular viewport pequeno via CSS não é o caso — testar a presença da classe é mais direto num request spec).
