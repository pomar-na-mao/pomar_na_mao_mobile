## Why

A tela Operacoes e o ponto de entrada das rotinas de campo, mas hoje todas as operacoes aparecem com peso visual parecido. Isso dificulta a leitura rapida do que esta disponivel agora, o que esta planejado e qual acao o usuario deve tomar primeiro.

## What Changes

- Reorganizar a tela Operacoes para destacar Inspecao como acao principal disponivel.
- Separar visualmente operacoes disponiveis de operacoes futuras, mantendo todas listadas.
- Melhorar a hierarquia do topo da tela com resumo operacional curto e informativo, sem transformar a tela em landing page.
- Tornar cards mais escaneaveis com iconografia consistente, status textual, descricao curta e area de toque acessivel.
- Manter estados bloqueados claros para toque, teclado e tecnologias assistivas, sem depender apenas de cor.
- Preservar navegacao existente: tocar em Inspecao abre a tela de Inspecao; operacoes futuras nao navegam.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `operations-menu`: melhora a apresentacao, hierarquia, responsividade e estados acessiveis do catalogo de operacoes.

## Impact

- Afeta a UI de `lib/features/operations/presentation/operations_view.dart`.
- Afeta os componentes e metadados de operacoes em `lib/features/operations/presentation/operation_definition.dart` e `widgets/operation_card.dart`.
- Afeta testes de widget da tela Operacoes para validar hierarquia, responsividade, navegacao e semantica.
- Nao altera APIs, banco de dados, sincronizacao, Supabase ou fluxo interno da Inspecao.
