## Why

O aplicativo ainda não oferece um registro georreferenciado e flexível para atividades de campo que não pertencem aos fluxos especializados de Inspeção, Pulverização ou MIPD. A Atividade permitirá documentar uma atividade realizada sobre uma rota ou área desenhada diretamente no mapa, com data, responsável e insumos rastreáveis.

## What Changes

- Adicionar o card habilitado **Atividade** na tela Operações, imediatamente abaixo de MIPD, com navegação para uma tela própria.
- Criar uma tela com o mapa e as plantas plotadas segundo os mesmos padrões cartográficos, visuais, responsivos e de desempenho usados pelas operações existentes.
- Permitir escolher o modo de desenho e registrar manualmente no mapa uma rota (`LineString`) ou uma área (`Polygon`), exigindo geometria válida antes de abrir ou salvar o formulário.
- Disponibilizar formulário para atividade realizada, data, hora, responsável, seleção opcional de uma máquina/trator de `public.machines` e seleção opcional de uma calda ativa de `public.mixtures`, exibindo os catálogos sem permitir alteração de seus dados.
- Salvar cada lançamento localmente antes da sincronização, mantendo geometria, campos do formulário, referência e snapshots da calda/composição e estado de sincronização para uso em campo sem conectividade.
- Adicionar persistência remota normalizada para os lançamentos da Atividade e sua calda, integrada a `field_operations`, `mixtures` e `mixture_inputs`, com índices, constraints, RLS/grants e seed idempotente do tipo de operação.
- Adicionar uma RPC transacional e idempotente `sync_activity_entries(p_payload jsonb)` para validar e gravar o lançamento completo e devolver os identificadores remotos de reconciliação.
- Gerar uma migration executável em `supabase/migrations` durante a implementação e atualizar `database.md`, incluindo **20.12. Processo Mobile: Atividade** e as tabelas/RPC no item 25 e no SQL consolidado.
- Adicionar testes Dart/Flutter e verificações SQL para domínio, persistência local, sincronização, desenho, formulário, navegação, acessibilidade e layout compacto.

## Capabilities

### New Capabilities

- `activity-operation`: Experiência da Atividade no mapa, desenho e validação de rota/área, preenchimento do formulário e seleção de uma calda com sua composição.
- `activity-offline-sync`: Persistência SQLite, fila local, contrato remoto, tabelas normalizadas e sincronização idempotente do lançamento completo via RPC.

### Modified Capabilities

- `operations-menu`: Adiciona Atividade como operação habilitada e navegável imediatamente após MIPD.
- `local-read-cache`: Inclui `public.machines`, `public.mixtures` e suas composições de `public.mixture_inputs` na revisão local compartilhada necessária ao formulário, preservando a última versão íntegra para uso offline.

## Impact

- **Flutter/Dart:** novos modelos, banco/local store, data source, repository, view model, tela, widgets de desenho/formulário/listagem e integração de dependências em `lib/features/operations`; reutilização das primitivas de mapa, plantas, modais e botões existentes.
- **Navegação:** novo card e fluxo de ida/volta em `operation_definition.dart`, `operations_view.dart`, `main_shell.dart` e testes correspondentes.
- **Cache local:** extensão do carregamento compartilhado para o catálogo de caldas e composições, além do banco SQLite próprio/versionado para lançamentos pendentes, erros e IDs remotos.
- **Supabase/Postgres/PostGIS:** tabelas de lançamento e snapshots, vínculo com `field_operations`/`mixtures`, seed do tipo, índices espaciais e relacionais, RLS, grants e RPC transacional idempotente.
- **Documentação:** atualização das descrições de tabelas/RPCs, seção 20.12 e script consolidado do item 25 em `database.md`, além da migration executável solicitada.
- **Qualidade:** testes unitários, de widget, integração e SQL; análise estática e validação da migration/advisors durante a implementação.
