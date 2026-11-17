# Auditoria de implementação

## Dependências e preflight

- O cliente Flutter usava `confirmedPlants` no modelo, SQLite, repositório, ViewModel e widgets; esses consumidores foram removidos. Os pontos GPS continuam somente no SQLite para gravação, retomada e cálculo offline.
- `field_operation_track_points` era consumida pelas versões antigas de `sync_reviewed_spraying_operation`, `get_spraying_operations`, pela sobrecarga `recalculate_operation_affected_plants(uuid, double precision)` e pela FK `plant_operation_history.nearest_track_point_id`.
- `operation_inputs` era consumida pelas versões antigas das RPCs de sincronização e listagem.
- `plant_operation_history` e as tabelas de ocorrências possuem consumidores de Inspeção e permanecem. Somente linhas cujo `operation_types.code = 'spraying'` são limpas.
- O `DROP` das duas tabelas e da coluna é executado sem `CASCADE`; portanto, uma dependência não auditada aborta a migration.

Contagens do banco-alvo antes da migration: 2 operações de pulverização, 44 pontos brutos, 3 insumos materializados, 13 linhas de histórico de plantas e 0 ocorrências/eventos de pulverização. Para Inspeção havia 2.812 linhas de histórico e 2.823 ocorrências/eventos, que são a guarda de preservação.

## Contratos canônicos

```json
{
  "localOperationId": "local-uuid",
  "deviceId": "device-uuid",
  "operation": {
    "startedAt": "2026-11-17T12:00:00Z",
    "finishedAt": "2026-11-17T12:30:00Z",
    "performedAt": "2026-11-17T12:30:00Z",
    "responsible": "Operador"
  },
  "route": {
    "localId": "route-uuid",
    "geojson": {"type": "LineString", "coordinates": [[-47, -21], [-47.001, -21.001]]},
    "distanceMeters": 150
  }
}
```

Resposta: `{"field_operation_id":"uuid","route_id":"uuid","sync_status":"synced","synced_at":"2026-11-17T12:31:00Z"}`. `trackPoints`, `inputs` e `confirmedPlants` são rejeitados, assim como rota ausente, GeoJSON inválido, LineString com menos de dois pontos ou período inválido.

`get_spraying_operation_plant_points(p_field_operation_id, p_route_radius_meters default 9)` retorna `{id, latitude, longitude}` em ordem de `id`; o raio deve estar em `(0, 100]` e plantas mortas/inexistentes não participam.

## SQL de guarda pré/pós

```sql
select ot.code, count(*)
from public.plant_operation_history h
join public.field_operations fo on fo.id = h.field_operation_id
join public.operation_types ot on ot.id = fo.operation_type_id
group by ot.code order by ot.code;

select ot.code, count(*)
from public.plant_occurrences o
join public.field_operations fo on fo.id = o.field_operation_id
join public.operation_types ot on ot.id = fo.operation_type_id
group by ot.code order by ot.code;

select ot.code, count(*)
from public.plant_occurrence_events e
join public.field_operations fo on fo.id = e.field_operation_id
join public.operation_types ot on ot.id = fo.operation_type_id
group by ot.code order by ot.code;
```

## Validação executada e bloqueios de ambiente

- `flutter analyze`: sem problemas.
- Suíte focada de Pulverização: 32 testes aprovados, incluindo payload, ciclo de sessão, UI responsiva, erro de sync, geometria e upgrade SQLite.
- Suíte completa de `test/features/operations`: 193 testes executados; somente dois testes preexistentes de `inspection_database_test.dart` falharam por esperar schema 10 quando o banco atual usa schema 12. As falhas também deixaram os diretórios temporários abertos no Windows e não são causadas por Pulverização.
- `openspec validate optimize-spraying-route-sync --strict`: válido.
- Advisors remotos: sem alertas de saúde. Os avisos de segurança/desempenho observados pertencem ao estado remoto anterior à migration; a nova RPC ainda não foi aplicada.
- A validação SQL local ficou bloqueada porque o Docker Desktop/engine não está disponível (`dockerDesktopLinuxEngine` inexistente). Por segurança, a migration não foi aplicada no projeto remoto apenas para teste. Permanecem pendentes os testes SQL, `EXPLAIN`, grants e o E2E online/offline.
