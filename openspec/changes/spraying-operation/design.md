## Context

O aplicativo móvel `pomar_na_mao_mobile` já dispõe de uma infraestrutura robusta para operações agrícolas, exemplificada pelo módulo de Inspeção (`InspectionView`, `InspectionViewModel`, `InspectionDatabase` e repositórios locais/remotos). O módulo de Operações expõe o catálogo de atividades em `operations_view.dart`, com o card de Pulverização atualmente desabilitado.

O backend Supabase/PostgreSQL conta com PostGIS e duas funções já desenvolvidas para pulverização:
1. `recalculate_operation_affected_plants`: calcula as plantas a até 9 metros da rota percorrida e registra no histórico.
2. `sync_reviewed_spraying_operation(p_payload jsonb)`: recebe a operação completa (metadados, rota GeoJSON, pontos GPS, insumos aplicados e plantas confirmadas) em uma única transação atômica.

Veja `proposal.md` para a motivação detalhada e os specs para os requisitos de negócio e cenários operacionais.

## Goals / Non-Goals

**Goals:**
- Implementar a tela de Pulverização (`SprayingView`) com mapa interativo, localização em tempo real, plotagem de plantas e barra de ações padronizada no rodapé com 4 botões.
- Permitir gravação contínua da rota GPS com controle local de Iniciar, Pausar e Finalizar.
- Calcular localmente no dispositivo (offline) as plantas afetadas em um raio padrão de 9 metros da rota, utilizando algoritmo geométrico com poda espacial por bounding box.
- Disponibilizar interface de revisão interativa de plantas (desmarcar falsos positivos ou incluir plantas manualmente com `matchSource`).
- Coletar insumos agrícolas (`operation_inputs`) e metadados operacionais do trator/máquina e operador através de formulário modal validado.
- Persistir operações no SQLite local (`spraying_database.dart` / `spraying_local_store.dart`), permitindo acumular múltiplos registros pendentes.
- Sincronizar pulverizações revisadas com Supabase através da RPC `sync_reviewed_spraying_operation`.
- Atualizar a seção 20.4 de `database.md` com todo o fluxo técnico, esquema local e contrato de integração.

**Non-Goals:**
- Rastreamento em background com app encerrado (headless background service) — o rastreamento é gerido durante a sessão do aplicativo.
- Streaming em tempo real de coordenadas para o servidor enquanto o trator se move (a operação é 100% offline-first; consolida e envia após revisão).
- Alteração da assinatura da RPC `sync_reviewed_spraying_operation` no Supabase, mantendo compatibilidade estrita com o contrato existente.

## Decisions

### 1. Separação Modular na Feature de Operações
- **Decisão**: Criar a estrutura dedicada de pulverização dentro de `lib/features/operations`:
  - `domain/spraying_models.dart`: entidades de domínio (`SprayingOperation`, `SprayingRoute`, `SprayingTrackPoint`, `SprayingInput`, `SprayingConfirmedPlant`, `SprayingStatus`).
  - `data/spraying_database.dart`: gerenciador SQLite específico para tabelas de pulverização ou extensão versionada do banco de operações local.
  - `data/spraying_local_store.dart`: operações CRUD offline para sessões, pontos, insumos e plantas.
  - `data/spraying_remote_data_source.dart`: chamada à RPC `sync_reviewed_spraying_operation`.
  - `data/spraying_repository.dart`: coordenação entre persistência local e sincronização remota.
  - `presentation/spraying_view_model.dart`: ChangeNotifier com gerenciamento de estado da sessão, mapa, filtros e sincronização.
  - `presentation/spraying_view.dart`: interface principal com mapa e barra inferior.
  - `presentation/widgets/*`: `SprayingActionCard`, `SprayingSessionModal`, `SprayingReviewModal`, `SprayingInputsModal`, `LocalSprayingsModal`.
- **Alternativa considerada**: Reaproveitar diretamente as classes de inspeção com flags condicionais. *Rejeitada* pois pulverização possui entidades distintas (rotas LineString, pontos GPS em série temporal, insumos com dosagens) que gerariam acoplamento indevido.

### 2. Algoritmo Geométrico Offline de Plantas Afetadas (9 Metros)
- **Decisão**: Executar o cálculo geométrico localmente no SQLite / Dart utilizando distância de ponto a segmento de reta (cross-track distance) em relação aos segmentos da rota ou distância euclidiana/haversine ao ponto de rastreamento mais próximo. Aplicar poda espacial prévia por Bounding Box da rota expandido em 9 metros para filtrar as plantas candidatas da zona antes do cálculo detalhado.
- **Alternativa considerada**: Chamar a RPC remota `recalculate_operation_affected_plants` durante a finalização. *Rejeitada* pois o requisito principal é funcionamento estritamente offline em campo, onde não há conectividade garantida.

### 3. Máquina de Estados da Sessão de Pulverização
- **Decisão**: A sessão possui os estados: `idle` (parado) → `recording` (gravando rota) → `paused` (pausado temporariamente) → `finished` (rota concluída) → `reviewing_plants` (revisando plantas) → `editing_inputs` (preenchendo insumos) → `reviewed` (pronto para sincronização) → `synced` (sincronizado com sucesso).
- **Alternativa considerada**: Permitir sincronização direta sem passar pelo preenchimento de insumos. *Rejeitada* pois o contrato da RPC exige obrigatoriamente pelo menos 1 insumo (`inputs >= 1`).

### 4. Estrutura das Tabelas SQLite Locais
- **Decisão**:
  - `local_spraying_operations`: `local_id`, `zone_id`, `title`, `operator_name`, `machine_name`, `tractor_identifier`, `notes`, `started_at`, `finished_at`, `status`, `sync_status`, `remote_field_operation_id`, `synced_at`, `created_at`.
  - `local_spraying_routes`: `local_id`, `operation_local_id`, `geojson`, `distance_meters`, `started_at`, `finished_at`.
  - `local_spraying_track_points`: `local_id`, `operation_local_id`, `latitude`, `longitude`, `speed_mps`, `accuracy_m`, `recorded_at`.
  - `local_spraying_inputs`: `local_id`, `operation_local_id`, `input_type`, `product_name`, `active_ingredient`, `dose`, `dose_unit`, `total_quantity`, `total_quantity_unit`, `notes`.
  - `local_spraying_confirmed_plants`: `local_id`, `operation_local_id`, `plant_id`, `match_source`, `matched_at`, `distance_meters`, `nearest_track_point_local_id`, `notes`.

### 5. UI/UX Padronizada com Design System
- **Decisão**: O `SprayingActionCard` adotará a mesma linguagem visual de `InspectionActionCard` (container flutuante com cantos arredondados R24, sombra suave, 4 botões com ícones e cores temáticas consistentes). O botão 3 concentrará as ações de Iniciar / Pausar / Finalizar e o botão 4 abrirá a listagem com badges de status.

## Risks / Trade-offs

- **[Precisão e ruído do GPS sob a copa das árvores]** → Filtrar pontos com precisão horizontal (`accuracy_m`) superior a 25 metros e descartar pontos duplicados/estacionários (< 1 metro de deslocamento), evitando polylines distorcidas.
- **[Desempenho no cálculo de plantas afetadas com muitas árvores]** → Aplicar indexação espacial ou bounding box prévio para restringir as plantas calculadas à área percorrida acrescida do buffer de 9m.
- **[Obrigatoriedade de insumos na RPC]** → A UI impedirá o avanço da finalização sem o cadastro de pelo menos 1 insumo válido, prevenindo falha de validação na RPC do Supabase.
