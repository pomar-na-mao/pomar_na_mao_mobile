## Purpose

Preservar inspeções e alterações de campo no dispositivo, permitindo recuperação e envio confiável ao Supabase com associação de todas as plantas modificadas.

## ADDED Requirements

### Requirement: Persistir a inspeção antes do envio
O aplicativo SHALL armazenar em SQLite a inspeção, seu conjunto de plantas e ocorrências, o catálogo de tipos e cada transição de ocorrência confirmada. Inspeções e alterações SHALL possuir identificadores locais estáveis, associados a uma identidade persistente da instalação. Fechar um modal, trocar de aba ou reiniciar o aplicativo SHALL NOT apagar registros persistidos.

#### Scenario: Recuperar rascunho após reinício
- **WHEN** o aplicativo é encerrado após editar plantas e reaberto antes de Atualizar
- **THEN** a inspeção em andamento, suas plantas e todas as transições salvas podem ser retomadas com as mesmas identidades

#### Scenario: Preservar sequência de alterações
- **WHEN** uma ocorrência é marcada, desmarcada e marcada novamente na mesma inspeção
- **THEN** as transições confirmadas são preservadas na ordem em que ocorreram e o estado apresentado corresponde à última transição
- **AND** reabrir o modal sem editar não gera transição adicional

### Requirement: Listar todas as inspeções locais
O terceiro botão SHALL abrir um modal consultando SQLite, com todas as inspeções locais, incluindo em andamento, pendentes, com erro e sincronizadas. Cada item SHALL apresentar data, quantidade de plantas alteradas e estado de sincronização. A lista SHALL permitir retomar o rascunho e tentar enviar inspeções finalizadas pendentes ou com erro.

#### Scenario: Abrir histórico offline
- **WHEN** o usuário abre Inspeções salvas sem internet
- **THEN** o aplicativo lista os registros locais do mais recente para o mais antigo sem depender de consulta remota

#### Scenario: Lista vazia
- **WHEN** não existem inspeções locais
- **THEN** o modal informa que nenhuma inspeção foi salva

#### Scenario: Sincronização concluída
- **WHEN** uma inspeção recebe confirmação de sucesso remoto
- **THEN** ela permanece no histórico local com status sincronizado e o identificador da operação remota

### Requirement: Consolidar uma operação com todas as plantas alteradas
O envio SHALL usar `sync_manual_inspection(p_payload)` ou uma nova RPC compatível quando necessária, mantendo `deviceId`, `localInspectionId`, `startedAt`, `finishedAt` e `plantsChanged`. Cada planta alterada SHALL aparecer uma única vez no lote com suas transições contendo `localChangeId`, `occurrenceTypeId`, `changeType` e `changedAt`. Plantas apenas carregadas ou visualizadas SHALL NOT integrar o lote. Os dados remotos SHALL preservar os efeitos do contrato fornecido em `field_operations`, `plant_operation_history`, `plant_occurrences` e `plant_occurrence_events`.

#### Scenario: Criar operação com múltiplas plantas
- **WHEN** uma inspeção com alterações em duas plantas é sincronizada
- **THEN** existe uma operação do tipo `manual_inspection`, um vínculo em `plant_operation_history` por planta alterada e as ocorrências e eventos correspondentes

#### Scenario: Adicionar ou resolver ocorrência
- **WHEN** uma transição adiciona uma ocorrência ausente ou desmarca uma ocorrência aberta
- **THEN** a adição cria ocorrência aberta e evento `added`, enquanto a remoção resolve a ocorrência com `resolved_at` e evento `removed`, sem excluir seu histórico

#### Scenario: Estado remoto já possui a ocorrência
- **WHEN** uma adição encontra uma ocorrência aberta no Supabase
- **THEN** a RPC segue o comportamento de atualização e evento `updated` do contrato existente
- **AND** remover sem ocorrência aberta não cria evento fictício
- **AND** atualizar ou resolver preserva a operação de origem da ocorrência, relacionando a nova ação pelo evento

### Requirement: Reenviar sem duplicar ou perder dados
O aplicativo SHALL congelar o lote finalizado e reutilizar as mesmas identidades e dados em cada retry, serializar envios e preservar a ordem das inspeções locais pendentes. Sucesso SHALL exigir uma resposta válida com `field_operation_id`. Falha, timeout ou encerramento SHALL manter dados recuperáveis. A sincronização SHALL produzir uma única operação e não repetir vínculos ou eventos ao reenviar o mesmo lote.

#### Scenario: Resposta perdida após commit remoto
- **WHEN** o Supabase confirma a transação internamente mas o dispositivo perde a resposta
- **THEN** o lote permanece reenviável e uma nova tentativa não duplica a operação, os vínculos ou os eventos

#### Scenario: Falhar offline ou interromper o aplicativo
- **WHEN** Atualizar é acionado sem conexão ou o app é encerrado durante o envio
- **THEN** a inspeção continua armazenada e pode ser reenviada pela lista local após reabertura
- **AND** o aplicativo não indica sincronização concluída antes da confirmação remota

#### Scenario: Evitar envios concorrentes e inversão local
- **WHEN** o usuário toca repetidamente em Atualizar ou pede envio de uma inspeção posterior enquanto existe outra anterior pendente
- **THEN** cada lote é enviado no máximo uma vez simultaneamente e a fila respeita a ordem de finalização, interrompendo o avanço em caso de falha anterior

### Requirement: Preservar compatibilidade remota
A integração SHALL preservar a RPC existente e verificar schema, retorno e permissões do projeto configurado antes de usar a sincronização. Se for necessária adaptação no servidor, SHALL ser criada uma RPC com novo nome via MCP Supabase, preservando os quatro destinos e as identidades do contrato. O aplicativo SHALL usar apenas as credenciais públicas já adotadas, sem incorporar chave privilegiada.

#### Scenario: Contrato implantado diverge do documentado
- **WHEN** a conferência remota encontra uma versão incompatível ou falta de acesso ao contrato
- **THEN** a implementação registra a divergência e prepara uma RPC separada se necessária, sem sobrescrever a função existente ou marcar inspeções incompatíveis como sincronizadas
