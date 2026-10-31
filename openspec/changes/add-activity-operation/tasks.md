## 1. Caracterização e fundação compartilhada

- [ ] 1.1 Adicionar testes de caracterização para mapa, marcadores/cluster, localização, controles, modais e botões reutilizados por MIPD/Pulverização; verificar que a suíte registra o comportamento atual antes de qualquer extração.
- [x] 1.2 Extrair ou ampliar somente as primitivas cartográficas e de formulário realmente compartilhadas pela Atividade, sem mover estado de domínio para widgets; verificar que todos os testes existentes de Inspeção, Pulverização e MIPD continuam passando.
- [x] 1.3 Definir builders/controladores injetáveis para testar mapa e conversão tela/coordenada sem Google Maps real; verificar com um teste de widget que a tela fake recebe plantas, geometria e callbacks corretos.

## 2. Catálogo compartilhado de insumos

- [x] 2.1 Criar o modelo de leitura do catálogo `inputs` com `id`, `name`, `type`, `active_ingredient`, `label_dose` e `dose_unit`, incluindo serialização tolerante aos campos opcionais; verificar testes unitários com linha completa e linha mínima.
- [x] 2.2 Versionar a persistência compartilhada para armazenar revisões de `inputs` isoladas por projeto, sem apagar filas locais existentes; verificar testes de criação, upgrade, reinício, conjunto vazio confirmado e troca de URL Supabase.
- [x] 2.3 Implementar busca remota paginada e single-flight de `public.inputs`, publicação atômica e fallback para a última revisão íntegra; verificar testes de múltiplas páginas, solicitações concorrentes, falha intermediária e ausência de nova leitura ao reabrir.
- [x] 2.4 Incluir `inputs` na ação coordenada Carregar dados usada pela Atividade, preservando snapshots já salvos; verificar teste de integração que plantas e catálogo só mudam juntos após sucesso completo.

## 3. Domínio geométrico e formulário

- [x] 3.1 Criar os modelos imutáveis de geometria, lançamento, item de insumo, estados de sincronização e resultado remoto conforme o padrão Dart do projeto; verificar round-trip de linha, polígono, snapshots opcionais e resposta RPC em testes unitários.
- [x] 3.2 Implementar o acumulador de vértices com amostragem por distância, desfazer, limpar, troca confirmada de modo e serialização GeoJSON; verificar testes de ordem, deduplicação, fechamento somente do polígono e limite de 2.000 vértices.
- [x] 3.3 Implementar validação pura de coordenadas, rota com dois pontos distintos, área com três vértices distintos/anel de quatro posições, segmentos nulos e autointerseção; verificar testes de geometrias válidas, bow-tie, duplicatas e limites de latitude/longitude.
- [x] 3.4 Implementar composição de Data e Hora no fuso local, normalização de atividade/responsável e regras dos insumos/dose aplicada; verificar testes com `30/10/2026 12:30`, espaços vazios, atividade sem insumos, item duplicado e dose de bula ausente.

## 4. Persistência local e fila offline

- [x] 4.1 Criar o banco SQLite da Atividade isolado por projeto com `installation`, `local_activity_entries`, `local_activity_entry_inputs`, FKs, índices e constraints; verificar testes de schema, origem do projeto e `PRAGMA foreign_keys`.
- [x] 4.2 Implementar o local store com salvamento transacional do lançamento e itens, consulta ordenada e reconciliação de IDs/estado/erro; verificar CRUD, rollback de item inválido, unicidade de insumo e persistência após reabertura.
- [x] 4.3 Recuperar itens deixados em `syncing` para estado elegível na abertura e manter itens `synced` consultáveis; verificar teste de reinício após interrupção e ausência de duplicação.
- [x] 4.4 Implementar o repository offline-first com `save`, `list`, `syncOne` e `syncAll`, single-flight e resposta remota parcial; verificar testes de falha de transporte, retry, lote concorrente e reconciliação individual.

## 5. Migration, tabelas e RPC Supabase

- [x] 5.1 Confirmar pelo CLI que o projeto usa migrations imperativas e criar o arquivo com `supabase migration new add_activity_operation`; verificar que o arquivo gerado está em `supabase/migrations` com o timestamp produzido pelo CLI.
- [ ] 5.2 Adicionar à migration o seed idempotente de `operation_types.code = 'activity'` e a tabela `activity_entries` com FK única para `field_operations`, geometria PostGIS, fingerprint, autoria, unicidade e checks; verificar aplicação limpa e consultas a constraints/índices, incluindo GiST e FKs indexadas.
- [ ] 5.3 Adicionar `activity_entry_inputs` com FK `RESTRICT` para `inputs`, cascade para o lançamento, snapshots, dose aplicada, unicidade e índices; verificar que duplicidade e exclusão destrutiva do insumo são rejeitadas sem perder histórico.
- [ ] 5.4 Habilitar RLS, revogar escrita direta e configurar grants mínimos nas duas tabelas; verificar como `anon`, `authenticated` e segundo usuário que inserts diretos são negados e nenhuma leitura indevida é aberta.
- [ ] 5.5 Implementar `sync_activity_entries(p_payload jsonb)` com `search_path` fixo, objetos qualificados, limites de lote/vértices/insumos/textos e validação de LineString/Polygon SRID 4326; verificar SQL para payloads válidos e falhas de tipo, anel, autointerseção, catálogo e limites.
- [ ] 5.6 Tornar a RPC transacional e idempotente por `(device_id, local_id)` com fingerprint, criando `field_operations`, detalhe e itens e retornando IDs por entrada; verificar retry idêntico, conflito divergente, rollback integral e ausência de duplicatas.
- [ ] 5.7 Revogar `EXECUTE` de `PUBLIC`, conceder somente a `anon` e `authenticated`, registrar `created_by` quando autenticado e testar o contrato nos dois modos; verificar que um usuário não obtém capacidade adicional de leitura ou mutação fora da RPC.
- [ ] 5.8 Executar os testes SQL/pgTAP disponíveis, `supabase migration list --local` e advisors de segurança/desempenho; corrigir alertas novos ou documentar justificativa explícita para a execução anônima controlada da RPC.

> Validação pendente em 27/10/2026: a Supabase CLI foi executada, mas o banco
> local não iniciou porque o Docker Desktop não está ativo
> (`dockerDesktopLinuxEngine` ausente). A migration e o SQL do item 25.5 foram
> comparados e são idênticos, mas as tarefas 5.2–5.8 permanecem abertas até a
> aplicação real, os casos SQL e os advisors serem executados.

## 6. Integração remota, dependências e sincronização

- [ ] 6.1 Implementar o remote data source para chamar `sync_activity_entries` e mapear a resposta canônica; verificar testes do nome/parâmetros da RPC, payload sem insumos, múltiplas entradas, resposta inválida e erro remoto.
- [x] 6.2 Integrar cache, banco, local store, data source, repository e `ActivityViewModel` em `AppDependencies`, incluindo descarte de recursos; verificar teste de composição com dependências reais e fakes após reinício.
- [x] 6.3 Implementar no ViewModel os estados de carga, desenho, formulário, lista e sincronização sem lógica de banco na View; verificar testes unitários de transições, validações, bloqueio de ações concorrentes e preservação do rascunho após erro.

## 7. Interface e navegação da Atividade

- [x] 7.1 Adicionar o card habilitado Atividade imediatamente após MIPD e implementar a navegação de ida/volta; verificar teste de widget com sete cards, ordem, semântica, estados habilitados/bloqueados e aba Operações preservada.
- [x] 7.2 Implementar `ActivityView` reutilizando estilo, plantas, cluster, localização e orçamento de renderização existentes; verificar testes de paridade, cache local sem leitura automática, estado sem cache, grande conjunto de plantas e layout em 320 px.
- [x] 7.3 Implementar os controles Rota/Área, modo de desenho por toque/arrasto, prévia `Polyline`/`Polygon`, Desfazer, Limpar e Continuar; verificar testes de widget para bloqueio de câmera durante desenho, troca confirmada, ações e geometria insuficiente/inválida.
- [x] 7.4 Implementar o modal rolável com Atividade realizada, Data, Hora e Responsável usando os padrões existentes; verificar entrada `roçagem`, seletores de data/hora, mensagens por campo e preservação do modal em falha local.
- [x] 7.5 Implementar pesquisa/seleção de `inputs`, lista com nome/princípio ativo/dose de bula, dose aplicada editável e remoção; verificar testes de catálogo vazio, campos opcionais, duplicidade, dose alterada, catálogo imutável e salvamento sem insumos.
- [x] 7.6 Persistir antes de fechar o modal, limpar o desenho somente após sucesso e apresentar feedback acessível; verificar teste de integração offline em que o lançamento reaparece completo após reiniciar.
- [x] 7.7 Implementar a lista de lançamentos salvos com resumo, tipo de geometria, contagem de insumos, status/erro e ações Sincronizar/Sincronizar todos; verificar testes de widget para fila vazia, sucesso, erro, retry, resultado parcial e bloqueio de toque duplicado.
- [x] 7.8 Permitir excluir uma operação não sincronizada da lista local após confirmação, removendo em cascade seus snapshots, e manter a ação desabilitada para registros sincronizados; verificar persistência SQLite, cancelamento, confirmação, estado desabilitado e atualização imediata da lista em teste de widget.
- [ ] 7.9 Adicionar filtro de plantas por zona na tela inicial, com o mesmo modal da Pulverização, filtragem e enquadramento da zona nos mapas inicial e de desenho, e manter todos os controles do modal de desenho em uma única linha; verificar ViewModel e widget em 320 px.

> Validação pendente em 28/10/2026: os testes unitário e de widget foram
> adicionados e passam pela análise estática, porém `flutter test` permaneceu
> bloqueado antes de iniciar os casos, sem saída do runner. `dart analyze` do
> projeto e `openspec validate add-activity-operation --strict`
> concluíram sem erros.

## 8. Documentação e validação final

- [x] 8.1 Atualizar `database.md` com as duas tabelas, índices, RLS/grants, tipo de operação, contrato/payload/retorno/limites da RPC e fluxo offline; verificar referências e nomenclatura consistentes em todo o documento.
- [x] 8.2 Adicionar exatamente `20.12. Processo Mobile: Atividade` após 20.11, descrevendo desenho, formulário, cache, salvamento local e sincronização; verificar numeração e exemplos de rota, área, data/hora e insumos.
- [x] 8.3 Incorporar tabelas, seed, índices, RLS, função e grants ao SQL consolidado do item 25 e ajustar catálogos/contagens e o script de remoção quando aplicável; verificar equivalência semântica entre `database.md` e a migration executável.
- [x] 8.4 Executar formatação, geração de código se aplicável, `dart analyze` e todas as suítes unitárias/widget/integradas relevantes; corrigir falhas até os comandos terminarem sem erro ou registrar limitação ambiental reproduzível.
- [ ] 8.5 Gerar build debug e validar manualmente em dispositivo o fluxo completo de mapa, desenho de rota/área, formulário, insumos, modo offline, reinício, sincronização autenticada/anônima e retry; registrar evidências e qualquer desvio antes de concluir a mudança.
- [x] 8.6 Renomear integralmente a funcionalidade para Atividade no app, SQLite, contrato Supabase, documentação e artefatos OpenSpec, preservando a migração automática dos dados locais e remotos legados; verificar ausência da nomenclatura anterior fora de código/migrations de compatibilidade, análise estática e migration incremental gerada pela CLI.
- [ ] 8.7 Substituir a inclusão individual de insumos pela seleção opcional de uma calda ativa, cachear `mixtures`/`mixture_inputs`, preservar snapshots da composição no SQLite, vincular `activity_entries.mixture_id`, atualizar a RPC e gerar migration incremental; verificar modelos, cache, persistência, payload, modal, documentação e testes.

> Implementação concluída em 29/10/2026 e análise estática sem diagnósticos.
> A tarefa permanece aberta porque `flutter test` voltou a bloquear antes de
> iniciar os casos, sem qualquer saída do runner, impedindo confirmar a suíte.

- [ ] 8.8 Adicionar Máquina/Trator opcional à Atividade, cachear `public.machines`, preservar referência e snapshots no SQLite, enviar somente `machineId`, validar e registrar a máquina na RPC, atualizar `database.md`/OpenSpec e gerar migration incremental; verificar domínio, cache, persistência, modal, payload, SQL e testes.

> Implementação concluída em 29/10/2026 e análise estática sem diagnósticos.
> A tarefa permanece aberta porque `flutter test` bloqueou antes de iniciar os
> casos, sem produzir saída, impedindo confirmar a suíte automatizada.

> Validação pendente em 27/10/2026: `flutter build apk --debug` não iniciou o
> Gradle porque não há JDK instalado/configurado (`JAVA_HOME` e `java`
> ausentes). O dispositivo Android está conectado, porém a validação manual
> depende primeiro de um APK gerado.
