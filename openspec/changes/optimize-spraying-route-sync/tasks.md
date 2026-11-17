## 1. Auditoria e contratos

- [x] 1.1 Auditar todas as dependências locais e remotas de `field_operation_track_points`, `operation_inputs`, `plant_operation_history.nearest_track_point_id`, `confirmedPlants` e `trackPoints`, registrando consumidores e bloqueios antes dos `DROP`s; verificar com buscas no repositório e consultas a `pg_depend`/catálogos no banco-alvo.
- [x] 1.2 Definir exemplos canônicos do novo payload e retorno de `sync_reviewed_spraying_operation` e do contrato de `get_spraying_operation_plant_points`; verificar que os exemplos omitem pontos brutos, insumos materializados e plantas confirmadas e cobrem os erros de validação.
- [x] 1.3 Levantar contagens pré-migration por tipo de operação em `plant_operation_history`, `plant_occurrences` e `plant_occurrence_events`; verificar que as consultas distinguem inequivocamente Pulverização de Inspeção para servirem de guarda da limpeza.

## 2. Modelo e persistência local Flutter

- [x] 2.1 Remover `SprayingConfirmedPlant`, `confirmedPlants` e contadores de plantas confirmadas dos modelos e da serialização remota, mantendo um tipo somente de apresentação para o resultado calculado se necessário; verificar com testes unitários de JSON/payload que `trackPoints` e `confirmedPlants` não são enviados.
- [x] 2.2 Atualizar o resultado de sincronização para aceitar somente identificadores, status e `synced_at`, removendo as comparações de contagem do repositório; verificar testes de sucesso, retry idempotente e erro de rede.
- [x] 2.3 Evoluir a versão do SQLite para remover `local_spraying_confirmed_plants` e os acessos associados sem remover os pontos GPS locais usados na gravação; verificar teste de upgrade sobre banco na versão anterior e abertura limpa de banco novo.
- [x] 2.4 Ajustar a reconstrução de pulverizações salvas para recalcular a prévia a partir da rota e do cache de plantas, sem lista persistida; verificar cenários online, offline e com zero plantas.

## 3. Revisão e experiência de sincronização

- [x] 3.1 Refatorar o ViewModel para manter o cálculo local/remoto e a lista de pontos afetados somente em memória, removendo `toggleAffectedPlant`, salvamento de confirmações e requisitos de quantidade; verificar testes unitários de finalizar, reabrir, preencher e salvar revisão.
- [x] 3.2 Remover dos widgets e do mapa todas as ações de marcar/desmarcar/adicionar plantas, mantendo as plantas visíveis durante a gravação da rota, além de marcadores destacados e contagem somente leitura na prévia; verificar com widget tests que a sessão em gravação conserva os pontos das plantas, que toques não alteram o estado e que a prévia aparece antes da sincronização.
- [x] 3.3 Atualizar a listagem e as mensagens de pulverizações salvas para não dependerem de plantas confirmadas ou contadores devolvidos pelo servidor; verificar renderização para `reviewed`, `syncing`, `synced` e `error` em largura de 320 px.
- [x] 3.4 Manter a validação de rota consolidada com ao menos dois pontos distintos antes do envio; verificar teste que uma rota inválida permanece local e não chama a RPC.
- [x] 3.5 Garantir que o início da gravação solicite as plantas sem bloquear o GPS e mantenha os pontos disponíveis no mapa durante a pulverização; verificar com teste de ViewModel e widget test no estado `recording`.

## 4. RPCs e migration Supabase

- [ ] 4.1 Criar a migration com `supabase migration new optimize_spraying_route_sync` e implementar `get_spraying_operation_plant_points(uuid, double precision)` usando `ST_DWithin` sobre `geography`, raio padrão 9 e limite 100; verificar resultados, exclusão de plantas mortas/inexistentes, ordem determinística e uso de índice com `EXPLAIN (ANALYZE, BUFFERS)`.
- [ ] 4.2 Proteger a nova RPC com `search_path = ''`, relações qualificadas, validação de escopo, `REVOKE` de `PUBLIC`/`anon` e `GRANT EXECUTE` apenas a `authenticated`/`service_role`; verificar chamadas permitidas, negadas e tentativa de acessar operação fora do escopo.
- [ ] 4.3 Substituir `sync_reviewed_spraying_operation` para validar o contrato reduzido e gravar atomicamente somente `field_operations` e uma `field_operation_routes`, preservando idempotência por `(device_id, local_id)`; verificar primeiro envio, retry, substituição da rota, rollback em erro e rejeição de `trackPoints`/`confirmedPlants`.
- [ ] 4.4 Atualizar `get_spraying_operations` e consumidores SQL para remover joins com `plant_operation_history` e `operation_inputs`, derivando dados espaciais somente quando solicitados; verificar filtros existentes, GeoJSON da rota e ausência de regressão na listagem principal.
- [ ] 4.5 Implementar a limpeza seletiva de registros legados vinculados ao tipo `spraying` em tabelas compartilhadas, preservando Inspeção e demais operações; verificar contagens pré/pós e executar a migration contra fixture com histórico misto.
- [ ] 4.6 Remover, sem `CASCADE`, `plant_operation_history.nearest_track_point_id`, `field_operation_track_points`, `operation_inputs` e seus índices somente após o preflight confirmar exclusividade; verificar que dependência inesperada aborta a migration e que as tabelas compartilhadas permanecem.
- [ ] 4.7 Incluir `NOTIFY pgrst, 'reload schema'`, consultas de verificação e orientação de rollback/restore point na migration; verificar `supabase db reset`/aplicação local desde zero e upgrade de um banco na versão anterior.

## 5. Documentação consolidada

- [x] 5.1 Atualizar o item 20.2 de `database.md` para descrever plantas somente leitura antes da sincronização, revisão apenas de dados, payload reduzido e consulta remota sob demanda; verificar coerência com os itens 20.12 e 20.14 e remover toda instrução de marcar/desmarcar plantas.
- [x] 5.2 Atualizar o item 25 e o catálogo de tabelas/RPCs de `database.md`, removendo estruturas abandonadas e adicionando SQL, contrato, segurança, índices, exemplos e rollback da nova RPC; verificar equivalência semântica entre o SQL consolidado e a migration.
- [x] 5.3 Revisar todas as ocorrências de `confirmedPlants`, `field_operation_track_points`, `operation_inputs` e contagens materializadas na documentação; verificar que referências remanescentes pertencem somente a contexto histórico explicitamente identificado ou foram removidas.

## 6. Validação integrada

- [x] 6.1 Executar formatação, `dart analyze` e os testes unitários/widget/integrados da Pulverização; verificar execução sem erros e registrar qualquer teste preexistente não relacionado.
- [ ] 6.2 Executar testes SQL de migration, grants, idempotência e preservação de Inspeção, além dos advisors disponíveis do Supabase; verificar ausência de alertas de segurança ou desempenho introduzidos pela mudança.
- [ ] 6.3 Validar de ponta a ponta uma pulverização online e outra offline: gravar rota, visualizar plantas, preencher dados sem editar marcadores, sincronizar e consultar os pontos pela nova RPC; verificar que o servidor cria apenas a operação e a rota e que retries não duplicam dados.
- [x] 6.4 Executar `openspec validate optimize-spraying-route-sync --strict` e revisar o diff final de código, migration e `database.md`; verificar que todos os cenários da spec possuem cobertura ou evidência registrada.
