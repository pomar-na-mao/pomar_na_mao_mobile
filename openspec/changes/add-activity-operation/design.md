## Context

O projeto já possui três fluxos cartográficos em `lib/features/operations`: Inspeção e MIPD compartilham cache de plantas, marcador/cluster por viewport, localização e estilo; Pulverização acrescenta geometria, persistência SQLite, revisão e sincronização por RPC. A tela Operações usa um catálogo ordenado de `OperationDefinition`, navegação por `MaterialPageRoute`, `ChangeNotifier`, repositories e composição manual em `AppDependencies`.

O banco remoto já contém `field_operations`, PostGIS, o catálogo `public.inputs`, o modelo de receitas `public.mixtures`/`public.mixture_inputs` e o catálogo `public.machines` documentado no item 20.15 de `database.md`. A Atividade precisa representar linha ou polígono, selecionar uma receita completa e opcionalmente associar uma máquina/trator sem editar os catálogos no dispositivo.

O projeto usa migrations imperativas em `supabase/migrations`, RLS em tabelas expostas e RPCs transacionais idempotentes para filas mobile. O aplicativo também opera sem sessão em fluxos existentes, portanto o desenho deve funcionar offline e a sincronização deve aceitar os mesmos papéis móveis sem expor escrita direta.

## Goals / Non-Goals

**Goals:**

- Reutilizar a experiência visual, os marcadores e o cache de plantas já estabilizados, mantendo lógica de desenho e formulário fora da View.
- Representar de forma canônica e validável uma rota ou área desenhada manualmente.
- Preservar local e remotamente os dados exatos vistos/preenchidos no momento da atividade.
- Tornar salvamento local e sincronização remota atômicos, idempotentes e recuperáveis.
- Integrar o lançamento ao cabeçalho comum `field_operations` sem forçar o modelo específico de pulverização.
- Entregar migration e documentação consolidada coerentes entre si.

**Non-Goals:**

- Rastrear GPS continuamente, calcular buffer de aplicação ou detectar automaticamente plantas afetadas.
- Permitir edição do catálogo `public.inputs` pela Atividade.
- Associar individualmente plantas contidas/interceptadas pela geometria nesta primeira versão.
- Editar ou excluir um lançamento remoto já sincronizado.
- Implementar visualização/relatórios da Atividade no aplicativo desktop.
- Introduzir sincronização automática em background; o envio continuará explícito pela lista local.

## Decisions

### 1. Feature dedicada com as camadas existentes do projeto

Criar modelos imutáveis de domínio, data source remoto, banco/local store, repository, `ActivityViewModel`, `ActivityView` e widgets menores dentro de `features/operations`. O ViewModel manterá o estado do desenho, formulário, catálogo e sincronização; a View apenas traduz gestos e renderiza o estado. As dependências serão compostas em `AppDependencies` e injetadas em `OperationsView` como ocorre com MIPD.

O cache compartilhado continuará como fonte de plantas e passará a armazenar as caldas ativas com suas composições; o banco próprio da Atividade conterá somente a fila mutável e seus snapshots. Isso evita duplicar milhares de plantas e evita misturar a fila com o ciclo de vida do cache de leitura.

Alternativa considerada: acrescentar flags e campos às classes de Pulverização. Rejeitada porque pulverização grava rota GPS, revisão de plantas e doses numéricas, enquanto a Atividade registra desenho manual, aceita polígono e atividade sem insumo.

### 2. Desenho por vértices ordenados sobre o mapa

O modo de desenho desabilitará temporariamente os gestos de câmera usados pelo mesmo toque e converterá toques/arrasto amostrado em coordenadas via controlador do mapa. Um acumulador de domínio removerá amostras muito próximas e produzirá uma lista ordenada. `Polyline` mostrará Rota; `Polygon` mostrará Área com fechamento apenas de apresentação até a validação.

A interface oferecerá seletor Rota/Área, Desfazer, Limpar e Continuar. Rota exige dois pontos distintos. Área exige três vértices distintos e serializa o primeiro novamente no final, resultando em ao menos quatro posições. Antes do formulário, o domínio verificará coordenadas, segmentos nulos e interseção entre segmentos não adjacentes. O algoritmo será puro Dart e testável, usando projeção local adequada à pequena extensão do pomar para os testes de segmentos; a RPC repetirá a validação definitiva com PostGIS.

Alternativa considerada: adicionar uma biblioteca de desenho sobre Google Maps. Rejeitada nesta etapa porque as primitivas necessárias já existem, uma dependência extra aumentaria risco de plataforma/licença e a lógica geométrica precisa continuar independente do widget.

### 3. Formulário modal e seleção de máquina/calda

Depois de validar a geometria, será aberto um bottom sheet/modal rolável seguindo o padrão de MIPD e Pulverização. Atividade, data, hora e responsável serão obrigatórios. Data e hora formarão um `DateTime` local, convertido para ISO-8601 UTC no armazenamento/payload; a UI sempre apresentará no fuso do dispositivo.

O seletor pesquisará a revisão local de caldas ativas. O usuário poderá escolher zero ou uma receita e visualizar nome, observações e toda a composição. Nenhuma informação da calda poderá ser alterada no fluxo mobile, incluindo nome, observações, insumos, doses e unidades; o usuário poderá apenas selecionar, trocar ou remover sua associação antes de salvar. A seleção cria snapshots locais de cada componente usando a dose definida em `mixture_inputs`, preservando o registro mesmo se a receita for alterada depois.

Alternativa considerada: enviar toda a composição escolhida pelo cliente. Rejeitada porque permitiria adulterar a receita. O payload leva somente `mixtureId`; a RPC consulta a composição autoritativa e grava os snapshots.

O campo opcional Máquina/Trator pesquisará o catálogo local de `public.machines` e permitirá escolher no máximo um equipamento. O formulário exibirá nome, marca e ano somente para consulta. O payload levará apenas `machineId`; a RPC validará a referência, preencherá `field_operations.machine_name` e preservará snapshots de nome e marca em `activity_entries`.

### 4. Persistência SQLite transacional e offline-first

Será criado um banco isolado por origem do projeto, seguindo `MipdDatabase`, com:

- `installation`: origem Supabase e `device_id` estável;
- `local_activity_entries`: `local_id`, `geometry_type`, GeoJSON canônico, atividade, `performed_at`, responsável, estado/erro, fingerprint e IDs remotos;
- `local_activity_entries` também preservará `machine_id`, nome e marca da máquina como snapshots opcionais;
- `local_activity_entry_inputs`: snapshots dos componentes da calda selecionada, mantidos também para compatibilidade com lançamentos anteriores.

O local store salvará cabeçalho e itens em uma única transação. Na inicialização, `syncing` volta para `pending`. O repository oferecerá `save`, `list`, `syncOne` e `syncAll`, com single-flight para lote e reconciliação individual. A lista local será a única fonte de consulta nesta versão, inclusive para itens sincronizados.

Alternativa considerada: enviar imediatamente sem armazenamento local quando houver rede. Rejeitada porque perde trabalho em falhas de conectividade e diverge dos fluxos de campo existentes.

### 5. Duas novas tabelas remotas vinculadas a `field_operations`

A migration criará o tipo de operação `activity` e as tabelas:

1. `activity_entries`: PK UUID; FK única e indexada para `field_operations`; `geometry_type` com check `route|area`; coluna `extensions.geography(Geometry,4326)`; atividade; `performed_at timestamptz`; responsável; `mixture_id` e `machine_id` opcionais com `ON DELETE RESTRICT`; snapshots de calda e nome/marca da máquina; `device_id`; `local_id`; fingerprint do payload; `created_by` anulável; timestamps; unicidade `(device_id, local_id)` e índice GiST da geometria.
2. `activity_entry_inputs`: PK UUID; FK indexada com cascade para o lançamento; FK indexada para `inputs` com `ON DELETE RESTRICT`; snapshots de nome, princípio ativo, dose de bula e unidade; dose aplicada textual; timestamps; unicidade `(activity_entry_id, input_id)`.

`field_operations` receberá `operation_type = activity`, `source = activity`, `title = activity`, `started_at = finished_at = performed_at` e `operator_name = responsible`. A tabela especializada preservará o contrato específico e permitirá consultas espaciais sem alterar o esquema compartilhado.

Para instalações que já executaram a versão com a nomenclatura anterior, uma migration incremental renomeará o tipo e o `source` para `activity`, as tabelas, constraints, índices e a RPC, preservando UUIDs, relacionamentos e dados existentes. As migrations históricas permanecem imutáveis para não quebrar o histórico já aplicado.

Alternativa considerada: adicionar geometria e campos diretamente a `field_operations`. Rejeitada porque tornaria colunas específicas anuláveis para todos os outros tipos e misturaria regras incompatíveis. Outra alternativa seria usar `field_operation_routes`; rejeitada porque essa tabela descreve rota e distância, não aceita semanticamente uma área.

### 6. RPC em lote, atômica e idempotente

`sync_activity_entries(p_payload jsonb)` aceitará `deviceId` e `entries[]` (máximo de 50). Cada entrada conterá identificador local, `geometryType`, GeoJSON, atividade, `performedAt`, responsável, `mixtureId` e `machineId` opcionais. A geometria terá no máximo 2.000 vértices e textos terão limites explícitos e compatíveis com a UI.

A função normalizará/validará o contrato, criará uma impressão digital do conteúdo canônico e verificará `(device_id, local_id)`. Retry idêntico retorna os IDs existentes; conteúdo divergente para a mesma chave gera erro. Para um item novo, a função valida que a calda existe, está ativa e possui composição, cria `field_operations`, `activity_entries` e snapshots a partir de `mixture_inputs`, retornando uma linha de reconciliação por entrada. Payloads legados sem `mixtureId` continuam aceitos para filas criadas pela versão anterior.

A função usará `SECURITY DEFINER` somente porque clientes não terão escrita direta, com objetos qualificados, `search_path` fixo, `EXECUTE` revogado de `PUBLIC` e concedido explicitamente a `anon` e `authenticated`. `created_by` receberá `auth.uid()` quando disponível. O payload anônimo não ganha capacidade de leitura; consultas do histórico permanecem locais nesta versão. RLS será habilitada nas duas tabelas, sem policies de escrita direta.

Alternativa considerada: múltiplos inserts pelo cliente. Rejeitada porque exporia tabelas, complicaria RLS e permitiria lançamentos parciais. Uma RPC por lançamento também foi rejeitada como único contrato para preservar a eficiência de `Sincronizar todos`.

### 7. Cache compartilhado de caldas e máquinas

O modelo de leitura conterá `mixtures` e a composição de `mixture_inputs` com os dados de apresentação de `inputs`, persistidos na mesma infraestrutura versionada que já isola snapshots por projeto. A ação explícita Carregar dados fará atualização coordenada com as plantas. A publicação preservará a versão anterior se qualquer página falhar. Lançamentos salvos nunca serão reconstruídos a partir do catálogo atualizado.

O mesmo ciclo de revisão persistente e publicação atômica incluirá `machines`, permitindo selecionar a máquina offline sem consulta remota ao abrir o modal.

Alternativa considerada: consultar `inputs` toda vez que o modal abrir. Rejeitada por impedir uso offline e causar leituras repetidas.

### 8. Compatibilidade visual, testes e documentação

O card Atividade será inserido imediatamente após MIPD sem alterar os cartões futuros. A tela reutilizará `OperationMapStyle`, `BoundedPlantMarkers`, `ActiveMapSurface`, localização e os componentes de botão/modal existentes. Builders injetáveis permitirão testes sem Google Maps real.

Serão adicionados testes unitários para geometria, serialização, validação, banco/local store, repository e ViewModel; testes de widget para ordem/navegação, desenho, modal, insumos, validações e 320 px; teste de integração do fluxo offline/reinício; e verificações SQL de constraints, RLS, autorização, rollback e idempotência. `database.md` será atualizado nas descrições de tabelas/RPCs, no catálogo, no drop consolidado quando aplicável, em 20.12 e no script completo do item 25.

## Risks / Trade-offs

- **[Traços com muitos pontos podem gerar UI/payload grandes]** → Amostrar por distância mínima, limitar 2.000 vértices, simplificar apenas a prévia quando necessário e preservar o GeoJSON canônico validado.
- **[Conversão de coordenadas de tela varia por densidade/plataforma]** → Isolar o conversor, usar `devicePixelRatio`, testar builder/controlador falso e validar manualmente em Android físico.
- **[Polígono autointersectante ou inválido passa no cliente]** → Repetir validação na RPC com PostGIS e rejeitar a transação antes de qualquer insert.
- **[Calda ou composição muda após o uso]** → Snapshots preservam o histórico e FKs `RESTRICT` impedem exclusão destrutiva de referências utilizadas.
- **[RPC `SECURITY DEFINER` concedida a `anon`]** → Nenhuma leitura/escrita direta, contrato fechado, limites rígidos, `search_path` fixo, idempotência, validação integral e revisão pelos advisors; documentar explicitamente a exposição intencional.
- **[Mudanças simultâneas em `operations-menu` e `local-read-cache`]** → Implementar sobre o estado atual do código e reconciliar os deltas ativos de MIPD antes de arquivar, evitando regressão para o main spec ainda defasado.
- **[Horário local durante mudança de fuso/DST]** → Converter uma única vez para UTC no salvamento e preservar o instante; apresentar novamente no fuso atual do dispositivo.

## Migration Plan

1. Confirmar o fluxo imperativo do projeto e criar a migration com `supabase migration new add_activity_operation`, sem inventar o timestamp manualmente.
2. Adicionar seed idempotente do tipo, tabelas, constraints, índices, RLS/grants e RPC; aplicar em banco local/ambiente de validação e executar casos SQL positivos e negativos.
3. Executar advisors de segurança e desempenho e resolver ou justificar alertas novos, especialmente a RPC anônima com `SECURITY DEFINER`.
4. Implementar modelos/cache/SQLite/repository e testes antes de ligar a UI; migrations locais devem preservar filas existentes das outras operações.
5. Integrar DI, menu, mapa, desenho, formulário e lista de sincronização, mantendo a funcionalidade atrás apenas do novo card.
6. Atualizar `database.md`, inclusive 20.12 e o SQL consolidado do item 25, garantindo equivalência semântica com a migration.
7. Executar formatação, geração quando aplicável, `dart analyze`, testes unitários/widget/integrados, build debug e validação manual em dispositivo.

Rollback de aplicativo: remover/ocultar o card e manter as tabelas locais/remotas para não perder registros. Rollback de banco: revogar `EXECUTE` da RPC antes de remover função/tabelas; só excluir dados após exportação/confirmação explícita, pois a reversão destrutiva não será automática.
