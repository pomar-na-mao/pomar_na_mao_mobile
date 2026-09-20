# Auditoria do contrato remoto

Data: 2026-09-18. Projeto confirmado por MCP: `uxschjkypkkzprbwuhxm`.
Consultas somente de leitura; nenhuma alteração remota aplicada.

## Tarefa 1.1 — concluída

O MCP está acessível nesta sessão. Foram inspecionadas as colunas de `plants`,
`occurrence_types`, `field_operations`, `plant_operation_history`,
`plant_occurrences` e `plant_occurrence_events`, além de constraints, índices,
políticas, privilégios e definição completa da RPC.

Assinatura implantada: `public.sync_manual_inspection(p_payload jsonb)`.
Retorno: `TABLE(field_operation_id uuid, created_occurrences_count integer,
updated_occurrences_count integer, removed_occurrences_count integer)`.
Função `SECURITY DEFINER`, `search_path = public, extensions`.
EXECUTE concedido a PUBLIC, postgres, anon, authenticated e service_role.
A definição obtida está preservada em `remote-sync-manual-inspection-legacy.sql`.

Índices/constraint de idempotência existentes:

- `uq_field_operations_device_local`: UNIQUE `(device_id, local_id)` WHERE
  `device_id IS NOT NULL AND local_id IS NOT NULL`.
- `uq_plant_operation`: constraint UNIQUE `(plant_id, field_operation_id)`.
- `uq_plant_occurrence_events_device_local`: UNIQUE
  `(device_id, local_change_id)` WHERE ambos não são nulos.

`updated_at` existe em `field_operations` e `plant_occurrences`.
`plant_occurrence_events` possui os campos de snapshots e identidade esperados;
`chk_plant_occurrence_events_action` aceita `added`, `updated`, `removed`, `reopened`.

Diferenças em relação à seção 24 de `database.md`:

- Faz INSERT simples em operações, sem upsert por dispositivo/ID local.
- Não escreve nem consulta `plant_occurrence_events`.
- Não ordena transições por `changedAt`/`localChangeId`.
- Na remoção usa `status = 'removed'`, em vez de `resolved`.
- Substitui a operação de origem ao atualizar/resolver ocorrências.
- Retorna `removed_occurrences_count`, em vez de `resolved_occurrences_count`.
- Não usa `search_path` vazio nem revoga EXECUTE de PUBLIC.

A função atual não atende ao contrato e não será usada pelo novo fluxo.
A criação de uma RPC separada, preservando a existente, já é prevista na tarefa 1.3.

## Tarefa 1.2 — bloqueio de leitura confirmado

`operation_types.code = 'manual_inspection'` existe, ID
`dc9436d4-e18a-4c8d-ab5e-0a1109f44993`.

Teste HTTP GET real com a chave pública de `AppConfig`, sem sessão de usuário:

| Tabela | Resposta a `select=id&limit=1` | RLS / política SELECT anon |
| --- | --- | --- |
| plants | HTTP 200, uma planta | Habilitado / existente |
| occurrence_types | HTTP 200, `[]` | Habilitado / ausente |
| plant_occurrences | HTTP 200, `[]` | Habilitado / ausente |

As três tabelas já concedem SELECT a anon e authenticated, mas as políticas de
catálogo e ocorrências só permitem authenticated. Contagem privilegiada por MCP:
20 tipos de ocorrência e 0 ocorrências. Portanto, o catálogo vazio do cliente é
causado por RLS; o resultado vazio de ocorrências, isoladamente, não comprova acesso.
O cliente não pode obter o estado inicial necessário para uma inspeção confiável.

## Decisão necessária

O design exige operação sem login e proíbe ampliar acesso por suposição.
Para manter esse fluxo, a proposta mínima é criar duas políticas SELECT para anon,
em `occurrence_types` e `plant_occurrences`, sem conceder escrita direta e sem
desabilitar RLS. SQL exato para revisão: `proposed-anon-read-policies.sql`.
Isso permite leitura dessas tabelas a qualquer cliente sem login com acesso à API.
O arquivo é uma proposta não aplicada, não uma migration executada.

Após decisão: atualizar o escopo de acesso nos artefatos, aplicar a mudança autorizada
pelo fluxo MCP/migration, repetir os testes de leitura, implementar e testar a nova
RPC, e continuar as demais tarefas. Nenhuma tarefa dependente foi marcada concluída.

Referência consultada: [Database Functions](https://supabase.com/docs/guides/database/functions).
