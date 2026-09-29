## MODIFIED Requirements

### Requirement: Consolidar uma operação com todas as plantas alteradas
O envio SHALL usar `sync_manual_inspection_v2(p_payload)`, mantendo `deviceId`, `localInspectionId`, `startedAt`, `finishedAt` e `plantsChanged`. Cada planta alterada (seja por transição de ocorrência ou por alteração no status de inexistência) SHALL aparecer uma única vez no lote em `plantsChanged` contendo `plantId`, o valor booleano `nonExistent` (ou `non_existent`) e suas transições contendo `localChangeId`, `occurrenceTypeId`, `changeType` e `changedAt`. A RPC `sync_manual_inspection_v2` SHALL atualizar na tabela `plants` a coluna `non_existent` conforme o valor informado para todas as plantas presentes em `plantsChanged`. Plantas apenas carregadas ou visualizadas sem alteração SHALL NOT integrar o lote. Os dados remotos SHALL preservar os efeitos do contrato fornecido em `plants`, `field_operations`, `plant_operation_history`, `plant_occurrences` e `plant_occurrence_events`.

#### Scenario: Criar operação com múltiplas plantas
- **WHEN** uma inspeção com alterações em duas plantas é sincronizada
- **THEN** existe uma operação do tipo `manual_inspection`, um vínculo em `plant_operation_history` por planta alterada e as ocorrências e eventos correspondentes

#### Scenario: Sincronizar alteração de planta inexistente
- **WHEN** a inspeção sincroniza plantas com o toggle "Planta Inexistente" modificado
- **THEN** a tabela `plants` no Supabase tem sua coluna `non_existent` atualizada conforme o valor indicado para cada uma das plantas enviadas em `plantsChanged`
- **AND** `updated_at` de cada planta afetada é atualizado na mesma transação

#### Scenario: Adicionar ou resolver ocorrência
- **WHEN** uma transição adiciona uma ocorrência ausente ou desmarca uma ocorrência aberta
- **THEN** a adição cria ocorrência aberta e evento `added`, enquanto a remoção resolve a ocorrência com `resolved_at` e evento `removed`, sem excluir seu histórico

#### Scenario: Estado remoto já possui a ocorrência
- **WHEN** uma adição encontra uma ocorrência aberta no Supabase
- **THEN** a RPC segue o comportamento de atualização e evento `updated` do contrato existente
- **AND** remover sem ocorrência aberta não cria evento fictício
- **AND** atualizar ou resolver preserva a operação de origem da ocorrência, relacionando a nova ação pelo evento
