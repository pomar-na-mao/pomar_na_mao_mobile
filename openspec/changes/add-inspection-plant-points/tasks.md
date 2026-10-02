## 1. Banco e contrato remoto

- [x] 1.1 Atualizar `database.md` no detalhamento separado com a RPC `sync_inspection_added_plants(p_payload jsonb)`, payload, retorno, validacoes, campos de `plants` preenchidos e grants/revokes, e verificar pesquisando pelo nome da RPC no arquivo.
- [x] 1.2 Atualizar o bloco "Query Unica" de `database.md` com a definicao executavel da RPC, grants/revokes e indice parcial de idempotencia em `plants(device_id, local_id)` quando aplicavel, e verificar pesquisando a RPC dentro da secao consolidada.
- [ ] 1.3 Implantar ou preparar a RPC no Supabase conforme o fluxo do projeto e verificar com uma chamada de teste que insere latitude, longitude e `non_existent`, mantendo os demais campos de planta em defaults.

## 2. Modelo e persistencia local

- [x] 2.1 Adicionar modelo Dart para planta adicionada localmente com `localId`, latitude, longitude, `nonExistent`, `zoneId`, status, erro, timestamps e `remotePlantId`, e verificar com testes de serializacao/desserializacao em `test/features/operations/inspection_models_test.dart`.
- [x] 2.2 Migrar `InspectionDatabase` para criar a fila `local_added_plants` com coluna `zone_id`, indices e reset de `syncing` para estado reenviavel na abertura, e verificar com testes de migracao em `inspection_database_test.dart`.
- [x] 2.3 Estender `InspectionLocalStore` com criar, listar, marcar sincronizando, confirmar sucesso e marcar erro para plantas adicionadas com `zoneId`, e verificar com testes em `inspection_local_store_test.dart`.

## 3. Repositorio e Supabase

- [x] 3.1 Estender `InspectionRepository` e `DefaultInspectionRepository` com adicionar/listar/sincronizar plantas adicionadas incluindo `zoneId` sem tocar em `syncPending()` de inspecoes, e verificar com testes em `inspection_repository_test.dart`.
- [x] 3.2 Estender `InspectionRemoteDataSource` e `SupabaseInspectionRemoteDataSource` com a chamada RPC dedicada (`zone_id` suportado) e nome injetavel, e verificar payload/parse de retorno em `supabase_inspection_remote_data_source_test.dart`.
- [x] 3.3 Garantir serializacao de envios para plantas adicionadas, tratamento de falha e retry separado da fila de inspecoes, e verificar com teste de integracao offline em `inspection_offline_sync_integration_test.dart`.

## 4. UI Flutter de inspecao

- [x] 4.1 Estender `InspectionMapConfig`/`InspectionView` para expor callback de toque longo em ponto livre do mapa sem interferir no toque em marcador existente, e verificar com widget test usando `mapBuilder` de teste.
- [x] 4.2 Criar modal de confirmacao de planta adicionada com coordenadas, selecao de zona (com valor inicial do filtro ativo), controle de `non_existent`, confirmar e cancelar, mantendo acessibilidade e alvo de toque minimo, e verificar com widget tests em `inspection_widgets_test.dart`.
- [x] 4.3 Criar modal/lista separada de plantas adicionadas com status, erro, coordenadas, `non_existent`, zona associada e acao de sincronizar, e verificar lista vazia, pendente, erro e sincronizada em widget tests.
- [x] 4.4 Atualizar `InspectionActionCard` com botao proprio para plantas adicionadas e layout responsivo por constraints, mantendo botoes legiveis em larguras compactas, e verificar em testes de 320, 768 e 1024 unidades logicas.
- [x] 4.5 Renderizar marcacoes locais pendentes/sincronizadas no mapa com distincao visual de plantas remotas e do valor `non_existent`, permitir remocao por duplo toque, e verificar por configuracao de marcadores em teste de widget/view model.

## 5. ViewModel e experiencia offline

- [x] 5.1 Estender `InspectionViewModel` com estado de plantas adicionadas, criacao a partir de coordenadas, refresh da lista, sincronizacao separada e mensagens de sucesso/erro, e verificar com `inspection_view_model_test.dart`.
- [x] 5.2 Garantir que cancelar o modal nao persiste planta e que confirmar nao altera inspecoes, ocorrencias ou `localInspections`, e verificar com testes de view model e widget.
- [x] 5.3 Garantir que plantas adicionadas sobrevivem a reinicio do banco/app e aparecem na lista propria antes de qualquer sincronizacao, e verificar com teste usando reabertura de `InspectionDatabase`.

## 6. Verificacao final

- [x] 6.1 Rodar `dart analyze` ou `flutter analyze` conforme o padrao do projeto e verificar sem novos erros.
- [x] 6.2 Rodar os testes de operations afetados (`inspection_*`, `supabase_inspection_remote_data_source_test.dart`, `operations_view_test.dart`) e verificar todos passando.
- [x] 6.3 Executar hot reload ou hot restart no app Flutter ja conectado, se houver conexao ativa disponivel, e verificar que a tela de Inspecao permanece navegavel.
- [x] 6.4 Validar o OpenSpec com `openspec validate add-inspection-plant-points --strict` e verificar sem erros.
