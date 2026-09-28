## Why

O aplicativo apresenta congelamentos ao navegar e reabrir, incluindo uma conta com 21.000 plantas. O relato e compativel com ANR, mas ainda nao existem traces que distingam bloqueio da UI, pressao de memoria, falha nativa ou espera de rede; precisamos eliminar caminhos de custo descontrolado e medir a estabilidade sem perder trabalho offline.

## What Changes

- Criar diagnostico reproduzivel de abertura, navegacao, background/retomada e encerramento do processo, com cargas pequenas, 21.000 e 50.000 plantas sinteticas.
- Compartilhar hidratacao e revisoes do cache; deslocar transformacoes pesadas para isolate e limitar lotes de leitura, persistencia e requisicoes concorrentes.
- Renderizar mapas por viewport/zoom com limite de objetos nativos e agrupamento que preserve todas as plantas, invalidacao por revisao e atualizacoes incrementais.
- Manter somente o mapa visivel ativo, suspender GPS e trabalho visual fora da tela e ignorar resultados assincronos obsoletos.
- Substituir bloqueio global durante leitura/atualizacao por estados locais recuperaveis, mantendo navegacao e cache anterior acessiveis.
- Alinhar o Inventario ao cache compartilhado ja previsto em `local-read-cache`, com totais da mesma revisao e sem hidratar todas as plantas apenas para contar.
- Preservar snapshots completos, isolamento por projeto, inspecoes pendentes e atualizacao remota explicita de plantas.

## Capabilities

### New Capabilities

- `runtime-stability`: orcamentos de responsividade, diagnostico de falhas e validacao de carga/ciclo de vida.

### Modified Capabilities

- `main-navigation`: navegacao disponivel durante cargas e preservacao de estado ao liberar recursos de telas inativas.
- `local-read-cache`: hidratacao compartilhada por revisao e processamento limitado, preservando publicacao atomica e alteracoes pendentes.
- `farm-map`: representacao limitada por viewport e revisao sem omitir plantas, aplicavel em conjunto com os requisitos de estabilidade dos mapas.
- `inventory-dashboard`: explicitar contagens locais consistentes, removendo ambiguidade sobre recarga remota ao reabrir.

## Impact

Afeta `lib/core/data/shared_read_repository.dart`, `lib/core/di/app_dependencies.dart`, `lib/core/ui/app_loading_controller.dart`, `lib/app/widgets/main_shell.dart`, repositorios e ViewModels de Fazenda/Inventario/Inspecao, mapas e armazenamento SQLite de inspecoes. Inclui testes de integridade offline, integracao e benchmarks em Android fisico; alteracoes de armazenamento local exigirao migracao nao destrutiva se forem necessarias.

Nao requer alteracoes de schema/RLS/RPC no Supabase, troca do SDK de mapas ou servico externo de telemetria. Uma biblioteca de indice espacial/agrupamento podera ser adicionada somente apos avaliar compatibilidade com as versoes fixadas e medir um prototipo. Esta entrega cria apenas artefatos de planejamento, sem mudar o aplicativo.
