## Why

A sincronização de pulverizações materializa uma linha por planta afetada, além dos pontos GPS brutos, embora a rota consolidada já seja suficiente para recalcular esse conjunto espacialmente. Isso aumenta o volume escrito, acopla a revisão manual ao histórico remoto e torna consultas e retries mais caros sem preservar uma informação que precise ser autoritativa.

## What Changes

- **BREAKING**: remover do modo de revisão a possibilidade de marcar, desmarcar ou confirmar plantas; a revisão passa a existir apenas para visualizar a rota e as plantas calculadas e preencher os dados da pulverização.
- Manter as plantas carregadas e visíveis no mapa durante a gravação da rota e, antes da sincronização, calcular local/remotamente as plantas afetadas para exibi-las destacadas, sem persistir escolhas manuais por planta.
- **BREAKING**: simplificar o payload e o retorno de `sync_reviewed_spraying_operation`, deixando de enviar/gravar `confirmedPlants` e pontos GPS brutos; persistir a operação, a rota consolidada e os dados operacionais necessários de forma idempotente.
- Deixar de criar registros de pulverização em `plant_operation_history` ou em qualquer ledger de ocorrências; `plant_occurrence_events` e `plant_operation_history` permanecem no schema porque atendem Inspeção e outros fluxos compartilhados.
- Criar uma RPC de consulta sob demanda para retornar as plantas ativas alcançadas por uma rota de pulverização, por `ST_DWithin` e raio padrão de 9 metros, seguindo o padrão de `get_field_activity_plant_points`.
- Atualizar as consultas de pulverizações para derivar contagem de plantas e zonas a partir da rota quando esses dados forem solicitados, sem depender de associações materializadas por planta.
- Gerar migration imperativa que substitua as RPCs, remova dados de associação antigos exclusivos de pulverização e elimine somente tabelas/colunas/índices que uma auditoria de dependências comprovar como exclusivos e órfãos; `field_operation_track_points` é candidata à remoção, enquanto estruturas compartilhadas não podem ser apagadas.
- Atualizar `database.md`, especialmente o processo de Pulverização no item 20 e o schema/RPCs consolidados no item 25, mantendo-o semanticamente equivalente à migration.

## Capabilities

### New Capabilities

- `field-spraying-operation`: Define o novo contrato da Pulverização baseada em rota, incluindo visualização prévia das plantas afetadas, revisão somente de dados, sincronização sem associações por planta e consulta espacial sob demanda.

### Modified Capabilities

Nenhuma capacidade consolidada em `openspec/specs` é alterada; o contrato de Pulverização ainda existe apenas na mudança anterior `spraying-operation`.

## Impact

- Flutter: modelos, banco SQLite, repositório/data source, ViewModel e widgets de revisão/listagem da Pulverização, além dos testes correspondentes.
- Supabase/Postgres/PostGIS: `sync_reviewed_spraying_operation`, `get_spraying_operations`, nova RPC espacial, limpeza seletiva de dados legados e possível remoção de `field_operation_track_points` após auditoria.
- Contratos: payload e retorno da sincronização mudam; clientes antigos que exigem `confirmedPlants` precisam ser atualizados junto com a migration.
- Documentação: itens 20 e 25 de `database.md` e catálogo de tabelas/RPCs.
