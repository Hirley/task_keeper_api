# Roadmap

Melhorias propostas mas ainda não implementadas. Cada item documenta o problema, a proposta e o critério de aceite — quando alguém (humano ou IA) for implementar, esse contexto substitui uma issue separada.

## Dashboard: reduzir redundância entre KPIs e "Distribuição por status"

**Status:** resolvido — o card "Distribuição por status" (barra empilhada + legenda) foi removido do painel inicial, em todos os tamanhos de tela. A iteração futura descrita abaixo continua em aberto.

**Problema (histórico):** no painel inicial (`app/views/dashboard/index.html.haml`), a mesma contagem por status aparecia duas vezes: nos 4 cards de KPI no topo (`Pendentes: 1`, `Em andamento: 1`, `Concluídas: 0`, cada um já com valor absoluto **e** percentual do total) e na barra empilhada + legenda do card "Distribuição por status" (mesmos 3 valores, mesmas 3 cores, com os mesmos links de drilldown pra Demandas filtrada). O card não trazia nenhuma informação que os KPIs já não cobrissem, então foi removido por completo em vez de só escondido em telas pequenas.

**Iteração futura (escopo maior, item separado):** usar o espaço liberado ativamente na coluna lateral (`.col-lg-4`) — por exemplo, listar as 2-3 demandas mais urgentes por nome dentro do card "Prazos" (hoje só mostra contagem), ou aumentar o limite de "Atividade recente" (`DashboardController#index`, hoje `.limit(5)`).

**Critério de aceite:**

- O card "Distribuição por status" não aparece em nenhum tamanho de tela.
- Specs de `spec/requests/dashboard_spec.rb` continuam passando.
