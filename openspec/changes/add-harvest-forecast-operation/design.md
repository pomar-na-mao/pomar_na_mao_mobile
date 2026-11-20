## Context

O módulo `lib/features/operations` já possui operações offline-first como **Ocorrências** (`InspectionView`), **MIPD** (`MipdView`), **Atividade** (`ActivityView`) e **Pulverização** (`SprayingView`), todas apoiadas pelo cache compartilhado de leitura (`SharedReadRepository` / `InspectionLocalStore`) e por bancos SQLite dedicados por operação para filas locais de sincronização.

A nova operação **Previsão de Safra** combina três comportamentos já estabelecidos em diferentes telas do projeto:
1. Layout base semelhante ao **MIPD**: mapa principal + card inferior com os botões **Carregar plantas** e **Marcações salvas**, acrescido de uma faixa intermediária com 5 botões circulares na mesma linha (`N`, `P`, `M`, `G`, `GG`).
2. Rastreamento visual no mapa igual à **Pulverização**: marcador do usuário com indicação de direção (`userMapMarkerForCourse` + `createDirectionalUserLocationMarkerIcon`) e desenho da rota marcada (`Polyline`) conforme o usuário se desloca, além dos marcadores das plantas (`BoundedPlantMarkers`).
3. Controle de câmera igual a **Ocorrências** (`InspectionCameraFollowState`): acompanha a posição do usuário inicialmente, mas suspende o reposicionamento automático assim que o usuário interage manualmente com o mapa (zoom/pan), permitindo inspecionar uma área grande sem que a câmera volte para o usuário a cada evento de GPS.

## Goals / Non-Goals

**Goals:**
- Incluir o card **Previsão de Safra** em `operation_definition.dart` dentro de `orchard-routine` (**Rotina do pomar**), logo após **Estoque**, e roteá-lo em `OperationsView`.
- Construir a vertical `harvest_forecast` em `lib/features/operations/{domain,data,presentation}` seguindo rigorosamente a arquitetura e o design system existentes.
- Gravar cada clique nos botões `N`, `P`, `M`, `G`, `GG` em uma tabela SQLite local com `latitude`, `longitude`, `classification` e `created_at`, exibindo os registros em **Marcações salvas** do mais novo para o mais antigo.
- Permitir alterar a classificação (`N`, `P`, `M`, `G`, `GG`) ou excluir registros locais diretamente no modal **Marcações salvas**, além de sincronizar individualmente ou todos os pendentes.
- Definir a migration SQL para o Supabase com a nova tabela `public.harvest_forecasts` e a RPC `public.sync_harvest_forecasts(p_payload jsonb)` que encontra a planta mais próxima pelas coordenadas e faz `UPSERT` por `plant_id` único, sem executar alterações via MCP.
- Atualizar `database.md` nos itens 20 e 25.

**Non-Goals:**
- Alterar o banco Supabase diretamente via ferramentas MCP (toda definição de banco será entregue exclusivamente em arquivo de migration SQL e documentada em `database.md`).
- Persistir a polilinha da rota percorrida no Supabase (a rota marcada é um auxílio visual em tempo real no mapa da tela, enquanto a sincronização persiste os pontos clicados nos botões `N`, `P`, `M`, `G`, `GG`).
- Exigir seleção manual de uma planta no mapa antes de clicar em `N`, `P`, `M`, `G`, `GG` (a vinculação com a planta mais próxima ocorre na sincronização via RPC pelas coordenadas do clique).

## Decisions

### 1. Estrutura em camadas na vertical `features/operations`

Seguiremos o mesmo padrão de MIPD e Atividade:
- `domain/harvest_forecast_models.dart`:
  - Enum `HarvestForecastClassification` com valores `n('N', 'Nenhuma')`, `p('P', 'Pequena')`, `m('M', 'Média')`, `g('G', 'Grande')`, `gg('GG', 'Muito grande')`.
  - Enum `HarvestForecastSyncStatus` (`pending`, `syncing`, `error`, `synced`).
  - Classe imutável `HarvestForecastMarking` contendo `localId`, `latitude`, `longitude`, `classification`, `createdAt`, `status`, `error`, `remoteId`, `remotePlantId`, `remoteZoneId`, `syncedAt`.
  - Classe `HarvestForecastSyncResult` mapeando o retorno da RPC.
- `data/harvest_forecast_database.dart`: banco SQLite `harvest_forecast_<project_uuid>.db` com tabelas `installation` e `local_harvest_forecast_markings` (colunas `local_id`, `latitude`, `longitude`, `classification`, `created_at`, `sync_status`, `error`, `remote_id`, `remote_plant_id`, `remote_zone_id`, `synced_at`).
- `data/harvest_forecast_local_store.dart`: métodos `create`, `list` (ordenado por `created_at DESC, local_id DESC`), `find`, `listSyncable`, `updateClassification` (atualiza `classification` e volta `sync_status` para `'pending'` e `error` para `null`), `delete`, `markSyncing`, `markError`, `markSynced`.
- `data/harvest_forecast_remote_data_source.dart`: chama `_client.rpc('sync_harvest_forecasts', params: {'p_payload': payload})`.
- `data/harvest_forecast_repository.dart`: integra `HarvestForecastLocalStore`, `HarvestForecastRemoteDataSource`, `InspectionLocalStore` e `refreshSharedCache` do `SharedReadRepository`.
- `presentation/harvest_forecast_view_model.dart`: gerencia carregamento de plantas, localização (`UserMapLocationState`, `SprayingLocationFilter`), pontos da rota marcada em memória para exibição de `Polyline` no mapa, criação rápida ao clicar em `N`/`P`/`M`/`G`/`GG`, alteração de classificação, exclusão e sincronização individual (`syncOne`) e em lote (`syncAll`).
- `presentation/harvest_forecast_view.dart` e `presentation/widgets/harvest_forecast_saved_markings.dart`: interface do mapa, barra de 5 botões circulares e modal de Marcações Salvas.

### 2. Comportamento do Mapa: Direção + Rota (Pulverização) e Zoom Livre (Ocorrências)

- **Plantas**: Utiliza `BoundedPlantMarkers` e `OperationMapStyle.createPlantMarkerIcon` para renderizar as plantas carregadas do cache compartilhado com alta performance.
- **Marcador do Usuário com Direção e Rota Marcada**:
  - `UserMapLocationState` calcula o `course` (direção) a partir das amostras GPS e alimenta `userMapMarkerForCourse(vm.mapLocation.course)`, alternando entre `_directionalUserIcon` (seta rotacionada e `flat: true`) e `_userIcon`.
  - A cada localização aceita pelo filtro de precisão/distância (`SprayingLocationFilter` / distância mínima >= 2.5m e precisão <= 25m), o `HarvestForecastViewModel` adiciona o ponto à lista da rota percorrida e expõe a `Polyline` correspondente no mapa (estilo pontilhado verde como em `SprayingViewModel.polylines`).
- **Acompanhamento de Câmera com Suspensão no Zoom/Pan**:
  - Reutiliza `InspectionCameraFollowState` envolvendo o `GoogleMap` com `Listener(onPointerDown: ..., onPointerUp: ..., onPointerCancel: ...)` e `onCameraMoveStarted: _handleCameraMoveStarted`.
  - Enquanto `_cameraFollowState.isFollowing` for `true`, novas posições GPS movem suavemente a câmera via `UserMapNavigator`.
  - Quando o usuário toca no mapa para dar zoom ou arrastar, `_cameraFollowState.cameraMoveStarted()` suspende o follow (`isFollowing = false`), permitindo observar qualquer área ampla sem ser reposicionado quando o GPS atualizar. Um botão `Icons.my_location` na `AppBar` permite retomar o acompanhamento quando desejado.

### 3. Barra de 5 Botões Circulares (`N`, `P`, `M`, `G`, `GG`)

- Posicionada entre o `Expanded` do mapa e o card inferior de ações (`Carregar plantas` / `Marcações salvas`).
- Os 5 botões circulares ficam alinhados horizontalmente na mesma linha (`Row` com espaçamento uniforme), cada um com rótulo claro (`N`, `P`, `M`, `G`, `GG`), tooltip semântico (`Nenhuma`, `Pequena`, `Média`, `Grande`, `Muito grande`), contraste elevado para leitura sob sol forte e feedback tátil/visual ao registrar a marcação.
- O clique captura a posição atual do usuário (`vm.mapLocation.location ?? vm.userLocation`) e grava imediatamente no SQLite.

### 4. Tabela `public.harvest_forecasts` e RPC `public.sync_harvest_forecasts` no Supabase

A migration SQL (`supabase/migrations/<timestamp>_add_harvest_forecast_operation.sql`) criará:

1. **Tabela `public.harvest_forecasts`**:
   - `id uuid primary key default gen_random_uuid()`
   - `plant_id uuid not null references public.plants(id) on delete cascade`
   - `zone_id uuid references public.zones(id) on delete set null`
   - `classification text not null` com `check (classification in ('N', 'P', 'M', 'G', 'GG'))`
   - `latitude double precision not null`
   - `longitude double precision not null`
   - `created_at timestamptz not null`
   - `updated_at timestamptz not null default now()`
   - Constraint de unicidade: `constraint harvest_forecasts_plant_id_key unique (plant_id)`

2. **Resolução Espacial da Planta Mais Próxima e Upsert na RPC**:
   - A RPC `public.sync_harvest_forecasts(p_payload jsonb)` percorre os itens recebidos em `p_payload->'markings'` (ou sincroniza item a item).
   - Para cada item (`localId`, `latitude`, `longitude`, `classification`, `createdAt`), constrói o ponto PostGIS `extensions.st_setsrid(extensions.st_makepoint(v_longitude, v_latitude), 4326)::extensions.geography` e busca a planta mais próxima em `public.plants` (filtrando `not non_existent` e `not is_dead`, ordenada pelo operador KNN `<->` sobre `p.location` com `limit 1`), obtendo `p.id` (`v_plant_id`) e `p.zone_id` (`v_zone_id`).
   - Executa `INSERT INTO public.harvest_forecasts (plant_id, zone_id, classification, latitude, longitude, created_at, updated_at) VALUES (v_plant_id, v_zone_id, v_classification, v_latitude, v_longitude, v_created_at, now()) ON CONFLICT (plant_id) DO UPDATE SET zone_id = excluded.zone_id, classification = excluded.classification, latitude = excluded.latitude, longitude = excluded.longitude, created_at = excluded.created_at, updated_at = now() RETURNING id, updated_at`.
   - Dessa forma:
     - `id` é único e gerado na criação do registro (`gen_random_uuid()`), sendo preservado quando o registro de `plant_id` é atualizado;
     - `plant_id` é único e referencia a planta mais próxima encontrada;
     - `zone_id` recebe `plant.zone_id` da planta encontrada;
     - `created_at` recebe a data/hora registrada pelo dispositivo no momento da marcação;
     - `updated_at` é sempre gerado pela RPC como a data/hora atual (`now()`), nunca vindo do dispositivo.

## Risks / Trade-offs

- **Clique sem GPS ativo ou sem plantas cadastradas no banco remoto** → Se o GPS não tiver posição no momento do clique no botão circular, o app exibe feedback imediato (`SnackBar`) orientando a aguardar a localização. Na sincronização, se não houver nenhuma planta cadastrada no banco remoto, a RPC retorna erro descritivo que fica registrado no item local para nova tentativa posterior.
- **Duas marcações próximas para a mesma planta no mesmo lote** → Processadas na ordem cronológica de envio, o `ON CONFLICT (plant_id) DO UPDATE` garante que a marcação mais recente substitua a anterior sem erro de chave duplicada.

## Migration Plan

1. Gerar o arquivo de migration SQL em `supabase/migrations/` com a tabela `public.harvest_forecasts`, índices, RLS/grants e a RPC `public.sync_harvest_forecasts(jsonb)`. (Não executar via MCP).
2. Atualizar `database.md` adicionando a subseção no item **20** e a especificação executável no item **25**.
3. Implementar as camadas `domain`, `data` e `presentation` no Flutter e conectar em `AppDependencies`, `operation_definition.dart` e `operations_view.dart`.
4. Validar com análise estática e testes automatizados (unitários e de widget).
