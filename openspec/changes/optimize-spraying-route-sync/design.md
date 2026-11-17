## Context

Ver [proposal.md](proposal.md) para a motivação. Hoje o mobile mantém pontos GPS e plantas confirmadas no SQLite e envia ambos para `sync_reviewed_spraying_operation`. A RPC grava `field_operations`, `field_operation_routes`, `field_operation_track_points`, `operation_inputs` e uma linha em `plant_operation_history` por planta; `get_spraying_operations` depende dessas associações para contagem e zona.

A rota consolidada em `field_operation_routes.route` já é uma `geography` indexada por GiST e as plantas possuem localização espacial indexada. O padrão de consulta desejado já existe em `get_field_activity_plant_points`: a listagem principal não materializa plantas, e o detalhe executa `ST_DWithin` somente quando precisa dos pontos.

`plant_operation_history` e `plant_occurrence_events` são estruturas compartilhadas e continuam necessárias para Inspeção. No estado atual do repositório, `field_operation_track_points` e `operation_inputs` são consumidas somente pela Pulverização; a implementação ainda deverá confirmar dependências no banco-alvo antes dos `DROP`s.

## Goals / Non-Goals

**Goals:**

- Tornar a rota consolidada a única evidência espacial remota da pulverização.
- Reduzir a sincronização remota a um upsert de `field_operations` e um upsert/substituição de `field_operation_routes`.
- Preservar a detecção e a visualização das plantas antes da sincronização, inclusive offline.
- Consultar plantas sob demanda com o mesmo contrato espacial de Atividade, seguro e indexável.
- Remover estruturas e dados exclusivos que deixem de ter consumidores sem afetar Inspeção.

**Non-Goals:**

- Preservar um snapshot histórico imutável das plantas alcançadas; o resultado representa as plantas elegíveis no momento da consulta.
- Alterar o raio operacional padrão de 9 metros ou permitir ajustes manuais por planta.
- Unificar as tabelas de rota de Pulverização e Atividade.
- Alterar os fluxos de ocorrências e histórico usados por Inspeção.

## Decisions

### 1. A rota consolidada será a fonte autoritativa remota

`sync_reviewed_spraying_operation` continuará recebendo `deviceId`, `localOperationId`, `operation` e `route`, mas não receberá `trackPoints`, `confirmedPlants` ou uma coleção de insumos materializada. Máquina, calda e seus nomes de snapshot permanecem em `field_operations`; a geometria, distância e período permanecem em uma única linha de `field_operation_routes`.

O retorno conterá `field_operation_id`, `route_id`, `sync_status` e `synced_at`. Contadores de pontos, insumos e plantas deixam de fazer parte do contrato. A função rejeitará explicitamente os campos removidos para detectar clientes antigos em vez de aceitar um envio parcialmente ignorado.

Alternativas consideradas:

- Manter `confirmedPlants` sem gravá-las: rejeitada porque preservaria payload, modelos e validações sem utilidade.
- Manter pontos brutos para auditoria: rejeitada porque o requisito é salvar somente a rota e eles duplicam a geometria consolidada.
- Manter `operation_inputs` como snapshot da calda: rejeitada porque `field_operations` já referencia `mixture_id` e guarda `mixture_name`; a proposta prioriza persistência mínima. Consultas que precisarem da composição usarão a receita atual de `mixture_inputs`/`stocks`, aceitando que ela não é um snapshot histórico.

### 2. A identificação das plantas será uma RPC separada e sob demanda

Será criada `public.get_spraying_operation_plant_points(p_field_operation_id uuid, p_route_radius_meters double precision default 9)`, retornando somente `id`, `latitude` e `longitude`. A função validará raio `(0, 100]`, tipo/fonte da operação, existência da rota e elegibilidade das plantas, usando `ST_DWithin(plant.location, route.route, radius)` sobre `geography`.

O detalhe usa o tamanho do resultado como contagem. `get_spraying_operations` deixa de juntar `plant_operation_history`; quando um resumo de zonas ou plantas for realmente necessário, ele será derivado pela mesma regra espacial, preferencialmente no detalhe para evitar executar a consulta geoespacial sobre toda a listagem.

A RPC seguirá o padrão de segurança atual: `SECURITY DEFINER`, `SET search_path = ''`, nomes totalmente qualificados, revogação de `PUBLIC`/`anon` e `EXECUTE` somente para `authenticated` e `service_role`. A implementação deve incluir a mesma verificação de escopo/tenant adotada pelas RPCs existentes; o grant de `authenticated` isoladamente não é autorização por linha.

Alternativa considerada: reutilizar `get_field_activity_plant_points`. Rejeitada porque essa RPC recebe `activity_entry_id`, aceita rota ou área e consulta `activity_entries`; sobrecarregá-la criaria um contrato ambíguo, e funções sobrecarregadas não são adequadas ao PostgREST.

### 3. As plantas permanecem visíveis durante a coleta e a prévia deixa de ser estado editável

O mobile carregará as plantas ao abrir o mapa e garantirá uma nova solicitação não bloqueante ao iniciar a sessão, mantendo os marcadores visíveis enquanto grava e retoma os pontos GPS no SQLite. Ao finalizar, consolida a rota e executa o cálculo já existente (`recalculate_operation_affected_plants` online ou `SprayingGeometryService` offline) para exibição. O resultado ficará em memória; ao reabrir uma pulverização não sincronizada, será recalculado a partir da rota e das plantas disponíveis.

Serão removidos o toggle por toque, `SprayingConfirmedPlant`, `confirmedPlants`, a tabela SQLite `local_spraying_confirmed_plants` e as validações de contagem confirmada. O status local `reviewed` permanece com o significado "dados operacionais preenchidos e rota pronta para sincronizar".

Alternativa considerada: persistir localmente a lista calculada somente para reabertura rápida. Rejeitada porque voltaria a criar dois estados autoritativos e exigiria invalidação quando a rota ou o cache de plantas mudasse.

### 4. A migration removerá somente estruturas exclusivas comprovadas

A migration imperativa será criada pelo fluxo de migration do projeto e executará, nesta ordem conceitual:

1. Fazer preflight das dependências de `field_operation_track_points`, `operation_inputs` e `plant_operation_history.nearest_track_point_id` no repositório e no banco-alvo.
2. Criar/substituir a RPC de pontos e validar grants antes de remover o contrato antigo.
3. Substituir atomicamente `sync_reviewed_spraying_operation` e `get_spraying_operations`.
4. Remover, por `operation_type = 'spraying'`, registros legados em ledgers compartilhados, incluindo eventos/ocorrências apenas se existirem e estiverem inequivocamente vinculados à pulverização; preservar todos os demais tipos.
5. Remover `plant_operation_history.nearest_track_point_id`, depois `field_operation_track_points` e seus índices.
6. Remover `operation_inputs` e seus índices, desde que o preflight confirme ausência de consumidores externos.
7. Recarregar o schema do PostgREST e executar consultas de verificação.

Os `DROP`s não usarão `CASCADE`; dependências inesperadas devem fazer a migration falhar para revisão. Como a limpeza destrói associações históricas, o rollback estrutural não recupera dados e exige backup/restauração. A implantação deve ocorrer em janela controlada, com contagens pré/pós e transação curta o suficiente para evitar contenção excessiva.

### 5. Os índices espaciais existentes serão reutilizados e verificados

A consulta deve manter `ST_DWithin` diretamente sobre as colunas `geography` para permitir uso dos índices GiST de `plants.location` e `field_operation_routes.route`. A implementação verificará esses índices e o índice de `field_operation_routes.field_operation_id`, e usará `EXPLAIN (ANALYZE, BUFFERS)` em volume representativo para impedir regressão por varredura sequencial desnecessária.

### 6. `database.md` será atualizado como especificação consolidada

O item 20.2 descreverá a prévia somente leitura, o novo payload e a consulta sob demanda; as referências dos itens 20.12 e 20.14 continuarão como precedente do padrão espacial. No item 25, o SQL consolidado removerá tabelas/colunas abandonadas, atualizará as RPCs e adicionará o contrato completo da nova função, grants, índices, rollback e exemplos. A migration e o documento devem ser semanticamente equivalentes.

## Risks / Trade-offs

- [A consulta deixa de representar o conjunto histórico exato de plantas] → Documentar que o resultado é dinâmico e baseado no estado atual; a rota histórica permanece imutável.
- [Consultas espaciais sob demanda podem elevar CPU em pomares grandes] → Executar somente no detalhe, limitar o raio a 100 m, manter GiST e validar o plano com volume representativo.
- [Cliente antigo pode falhar após a migration] → Tratar como mudança coordenada, atualizar o app antes/junto da migration e retornar erro explícito para payload obsoleto.
- [`DROP TABLE` pode atingir integrações fora deste repositório] → Fazer preflight no banco-alvo, não usar `CASCADE` e abortar diante de dependências inesperadas.
- [Limpeza de dados legados é irreversível sem backup] → Registrar contagens, produzir backup/restore point e declarar rollback de dados como restauração.
- [A receita atual da calda pode divergir da aplicada historicamente] → Exibir `mixture_name` armazenado na operação e documentar que a composição detalhada não é mais snapshot; se auditoria legal exigir snapshot, isso demandará capacidade futura separada.

## Migration Plan

1. Implementar e testar o novo contrato Flutter, incluindo upgrade do SQLite e recálculo ao reabrir revisões.
2. Criar a migration via Supabase CLI, depois revisar manualmente SQL, locks, grants e ausência de `CASCADE`.
3. Em ambiente de teste, carregar dados com pulverizações e inspeções misturadas; registrar contagens e plano da consulta espacial.
4. Aplicar a migration e verificar idempotência, rollback transacional em erro, preservação dos dados de Inspeção e resposta da nova RPC.
5. Atualizar e validar `database.md`, itens 20 e 25, contra a migration final.
6. Implantar app e banco de forma coordenada em janela controlada, com restore point anterior à limpeza.

Rollback: reimplantar as versões anteriores das RPCs e recriar tabelas/colunas removidas por migration de reversão. Recuperar associações e pontos antigos somente a partir do backup; novos envios feitos no contrato de rota não possuem dados por planta para reconstrução exata.
