## 1. Caracterização e fundação compartilhada

- [x] 1.1 Adicionar testes de caracterização para estilos, marcadores, localização, câmera e estratégia de renderização do mapa da Inspeção; verificar que a suíte registra o comportamento atual antes da extração.
- [x] 1.2 Extrair as primitivas cartográficas sem estado específico para componentes/serviços compartilhados em `features/operations`; verificar que os testes da Inspeção e uma comparação visual/widget confirmam paridade antes e depois da refatoração.
- [x] 1.3 Adicionar a dependência escolhida para captura pela câmera e armazenamento de arquivo durável, além das permissões Android/iOS; verificar `flutter pub get`, análise estática e build debug nas plataformas configuradas.

## 2. Catálogo e atualização completa do cache

- [x] 2.1 Acrescentar `category` ao modelo e à tabela SQLite de `occurrence_types`, com migration que invalide ou reconstrua snapshots antigos sem perder filas locais; verificar testes de upgrade, reinício e cache vazio confirmado.
- [x] 2.2 Alterar a origem compartilhada para buscar e persistir o catálogo completo de ocorrências e criar visões em que Inspeção exclui e MIPD inclui somente `PEST_DISEASE`; verificar testes unitários com todas as quatro categorias e ausência de consultas/cache duplicados.
- [x] 2.3 Implementar uma rotina single-flight e atômica de atualização explícita de fazenda, zonas, regiões, plantas, catálogo e ocorrências abertas; verificar que uma falha intermediária mantém o snapshot anterior e que consumidores concorrentes recebem uma única nova revisão.
- [x] 2.4 Ligar Carregar Plantas da Inspeção à rotina completa compartilhada, preservando alterações locais pendentes; verificar em teste de integração que o botão atualiza também o catálogo/categoria e não apenas `plants`.

## 3. Domínio e persistência local MIPD

- [x] 3.1 Criar modelos MIPD para partes da planta, marcação, estados de sincronização e payload/resultado remoto, validando seleção única `PEST_DISEASE` e partes não vazias; verificar testes unitários de serialização e entradas inválidas.
- [x] 3.2 Criar a tabela SQLite `local_mipd_markings`, database e local store conforme o padrão do projeto, com IDs estáveis, partes canônicas, caminhos de foto, estados, erros e IDs remotos; verificar testes de CRUD, reinício e recuperação de itens deixados em `syncing`.
- [x] 3.3 Implementar o serviço de captura que copia a foto confirmada para diretório gerenciado antes de salvar e remove arquivos temporários quando apropriado; verificar testes com captura, cancelamento, negação de permissão, falha de cópia e marcação sem foto.

## 4. Backend, RPC e Storage

- [x] 4.1 Gerar pelo fluxo Supabase do projeto uma migration `add_mipd_operation` com seed idempotente do tipo `mipd`, tabela `mipd_markings`, FKs indexadas, unicidades e constraints de partes; verificar aplicação limpa, reaplicação/idempotência prevista e constraints com SQL de validação.
- [x] 4.2 Adicionar à migration o bucket privado `mipd-plant-photos`, limites/MIME e políticas `select`/`insert`/`update`/`delete` por proprietário e prefixo `auth.uid()`; verificar com dois usuários autenticados que upsert próprio funciona e acesso cruzado é negado.
- [x] 4.3 Implementar na migration a RPC autenticada `sync_mipd_markings(p_payload jsonb)`, com validação de categoria/partes/foto, uma operação por marcação, `operation_type = 'mipd'`, `source = 'mpid'` e gravações em `plant_operation_history`, `plant_occurrences`, `plant_occurrence_events` e `mipd_markings`; verificar casos de ocorrência nova e já aberta contra a semântica de `sync_manual_inspection_v2`.
- [x] 4.4 Tornar a RPC transacional e idempotente por `(device_id, local_id)`, revogar `PUBLIC`/`anon` e conceder somente privilégios necessários a `authenticated`; verificar repetição do mesmo payload sem duplicatas, rollback de lote inválido e rejeição de chamada anônima.
- [x] 4.5 Executar os testes SQL/pgTAP disponíveis e os advisors de segurança/desempenho após aplicar a migration em ambiente de validação; verificar que não restam alertas novos sem justificativa documentada.

## 5. Sincronização Flutter

- [x] 5.1 Criar o remote data source para upload autenticado no caminho determinístico `{auth.uid}/{device_id}/{local_id}.{ext}` e chamada de `sync_mipd_markings`; verificar testes de construção do caminho, ausência de foto, erro de upload e mapeamento da resposta.
- [x] 5.2 Criar o repository MIPD para salvar offline, persistir `remote_photo_path` antes da RPC, sincronizar item/lote e conciliar IDs/erros; verificar que retries de upload/RPC não duplicam objeto nem registros e que falhas mantêm os itens recuperáveis.
- [x] 5.3 Integrar database, stores, data source, repository e view model no `AppDependencies`, incluindo descarte/recuperação de recursos; verificar teste de composição e inicialização após reinício.

## 6. Interface e navegação MIPD

- [x] 6.1 Adicionar o card habilitado MIPD imediatamente após Pulverização e a navegação de ida/volta em `operation_definition.dart` e `operations_view.dart`; verificar teste de widget da ordem dos seis cards, estados habilitados/bloqueados e preservação da aba Operações.
- [x] 6.2 Implementar `mipd_view.dart` com as primitivas compartilhadas do mapa, posição do usuário e card inferior contendo Carregar Plantas e Marcações salvas; verificar testes de paridade com a Inspeção, layout em 320 px e conjunto grande de marcadores.
- [x] 6.3 Ligar Carregar Plantas do MIPD à atualização completa compartilhada com progresso, sucesso e erro recuperável; verificar que todos os conjuntos são renovados atomicamente e a última revisão permanece visível durante falha.
- [x] 6.4 Implementar o modal de planta com seletor único `PEST_DISEASE`, multisseleção Folha/Ramo/Tronco/Raiz/Fruto e validações obrigatórias; verificar testes de widget para filtro, múltiplas partes, catálogo vazio, cancelamento e bloqueio de salvar inválido.
- [x] 6.5 Implementar o card pontilhado de foto com câmera, pré-visualização, nova captura e remoção, mantendo a foto opcional; verificar testes de widget para permissão concedida/negada, cancelamento, prévia e salvamento sem foto.
- [x] 6.6 Persistir a marcação antes de fechar o modal e apresentar feedback sem exigir rede; verificar teste de integração offline em que o item reaparece em Marcações salvas após reiniciar o aplicativo.
- [x] 6.7 Implementar Marcações salvas com dados, miniatura, status/erro e ações Sincronizar e Sincronizar todas; verificar testes de widget e integração para sucesso parcial no cliente, retry e bloqueio contra disparos duplicados.

## 7. Documentação e validação final

- [x] 7.1 Atualizar `database.md` com tabela/bucket, catálogo e contrato da RPC, payload/retorno, distinção `mipd`/`mpid`, ordem do upload e tabelas afetadas; verificar que o item 20 contém **Processo Mobile: MIPD**, o item 25 contém a RPC e o SQL consolidado corresponde à migration.
- [x] 7.2 Executar formatação, geração de código se aplicável, análise estática e todos os testes unitários/widget/integrados relevantes; verificar que os comandos terminam sem erros ou registrar explicitamente qualquer limitação ambiental.
- [ ] 7.3 Validar manualmente em dispositivo o fluxo completo: cache antigo, Carregar Plantas, mapa/localização, marcação com e sem foto, modo offline, reinício, sincronização individual e em lote; verificar no Supabase os registros das cinco tabelas, `source = 'mpid'` e o objeto privado.
- [x] 7.4 Revisar a migration final e o plano de implantação/rollback, garantindo backend antes do aplicativo e preservação de tabela/bucket com dados; verificar que os artefatos entregues permitem execução sem SQL manual fora da migration.
