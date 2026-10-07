## Why

Atualmente, o aplicativo móvel do Pomar na Mão disponibiliza apenas a rotina de Inspeção no módulo de Operações, deixando o card de Pulverização bloqueado como funcionalidade futura. No manejo agrícola, o registro preciso das pulverizações (trator/máquina, operador, insumos, calda/dosagem, rota percorrida e árvores atingidas) é crítico para o controle fitossanitário, rastreabilidade e governança de custos. Habilitar essa operação com suporte offline-first, rastreamento contínuo de rota GPS, cálculo geométrico de plantas afetadas com revisão manual e sincronização consolidada atende a uma necessidade primária dos operadores de campo.

## What Changes

- **Habilitação da Pulverização no menu de Operações**: Ativa o card "Pulverização" em `operations_view.dart`, permitindo navegação para a nova tela de Pulverização.
- **Tela de Pulverização (`SprayingView`)**: Interface dedicada com mapa interativo, localização do usuário em tempo real, plotagem de plantas carregadas e barra de ações padronizada no rodapé (estilo `InspectionActionCard`).
- **Barra de Ações da Pulverização**:
  1. *Carregar plantas*: Carrega as plantas da base local/remota para o mapa.
  2. *Filtrar por zona*: Modal para seleção e filtro de plantas por zona/talhão.
  3. *Sessão de Rastreamento (Controle de Operação)*: Modal de controle com ações para Iniciar (Start), Pausar (Pause) e Finalizar (Finish) a gravação da rota GPS em campo.
  4. *Pulverizações Salvas*: Modal de listagem de pulverizações salvas localmente (rascunho, pendentes de sincronização, sincronizadas e com erro), permitindo sincronização em lote ou individual.
- **Rastreamento de Rota GPS em Tempo Real**: Coleta de pontos GPS (`trackPoints`) com timestamp, latitude, longitude, precisão e velocidade, desenhando a rota no mapa (`field_operation_routes`) e calculando a distância total percorrida.
- **Detecção e Revisão de Plantas Afetadas**:
  - Ao finalizar a rota, o sistema identifica automaticamente as plantas pulverizadas utilizando critério de proximidade geométrica (buffer configurável, padrão 9 metros da rota/pontos), espelhando a lógica da RPC `recalculate_operation_affected_plants`.
  - Interface de revisão em que o operador pode visualizar as plantas autoidentificadas, confirmar, desmarcar ou adicionar manualmente plantas adicionais no mapa/lista (`matchSource`: `auto_matched` ou `manual_added`).
- **Modal de Insumos da Pulverização (`operation_inputs`)**:
  - Registro de operador (`operatorName`), título, máquina (`machineName`), identificador do trator (`tractorIdentifier`) e observações.
  - Cadastro de um ou mais insumos aplicados: tipo de insumo (`inputType`), nome do produto (`productName`), ingrediente ativo (`activeIngredient`), dose (`dose`), unidade da dose (`doseUnit`), quantidade total aplicada (`totalQuantity`), unidade total (`totalQuantityUnit`) e observações adicionais.
- **Armazenamento Local Offline-First (SQLite)**:
  - Criação de tabelas locais para gerenciar operações de pulverização, pontos de rota, insumos e plantas confirmadas, suportando múltiplos registros finalizados pendentes de sincronização.
- **Sincronização com Supabase via RPC**:
  - Envio dos dados revisados através da RPC remota `sync_reviewed_spraying_operation(p_payload jsonb)`, tratando respostas de sucesso, validações e retries resilientes.
- **Atualização da Documentação Técnica**:
  - Preenchimento da seção 20.4 de `database.md` detalhando todo o fluxo de dados, estrutura do SQLite e payload da RPC.

## Capabilities

### New Capabilities
- `field-spraying-operation`: Fluxo operacional completo de pulverização em campo com mapa, gravação de rota GPS, cálculo e revisão de plantas pulverizadas, coleta de insumos, persistência offline-first em SQLite e sincronização com Supabase via RPC `sync_reviewed_spraying_operation`.

### Modified Capabilities
- `operations-menu`: Atualização do catálogo de operações para habilitar o card de Pulverização (anteriormente bloqueado/em breve), direcionando para a nova tela de Pulverização enquanto preserva o comportamento dos demais cards.

## Impact

- **Código Mobile (`lib/features/operations`)**:
  - Nova tela `SprayingView` e ViewModel associado (`SprayingViewModel`).
  - Novos widgets: `SprayingActionCard`, `SprayingSessionModal`, `SprayingInputsModal`, `SprayingReviewModal` e `LocalSprayingModal`.
  - Novos modelos de domínio em `spraying_models.dart`.
  - Camada de dados local em `spraying_database.dart` / `spraying_local_store.dart` (ou extensão do banco de operações).
  - Repositório e data source remoto para invocar `sync_reviewed_spraying_operation`.
  - Modificação em `operation_definition.dart` e `operations_view.dart` para habilitar `spraying`.
- **APIs / RPCs**:
  - Utilização da RPC `sync_reviewed_spraying_operation` e alinhamento com a lógica de `recalculate_operation_affected_plants`.
- **Documentação**:
  - Atualização da seção 20.4 em `database.md`.
