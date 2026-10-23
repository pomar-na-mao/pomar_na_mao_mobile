## Context

O aplicativo já possui uma vertical de Inspeção offline em `features/operations`, com mapa de alta densidade, posição do usuário, cache SQLite compartilhado, fila local e sincronização por RPC. A Pulverização segue a mesma arquitetura em camadas, mas mantém banco e fila próprios. O MIPD deve parecer e se comportar exatamente como o mapa da Inspeção, embora seu registro tenha outro ciclo de vida: uma ocorrência exclusivamente `PEST_DISEASE`, várias partes afetadas e uma foto opcional que precisa ser persistida localmente e enviada ao Storage antes da mutação transacional no Postgres.

Hoje o cache local de `occurrence_types` não guarda `category`, e a origem remota da Inspeção já filtra `PEST_DISEASE`. Para que dois consumidores apliquem filtros opostos sem manter catálogos divergentes, o cache passará a armazenar o catálogo completo com a categoria. A ação Carregar Plantas também deixa de significar apenas uma leitura de `plants`: tanto na Inspeção quanto no MIPD ela será a atualização explícita e coordenada de todos os dados compartilhados requeridos pelas rotinas de campo.

No backend, `sync_manual_inspection_v2` define a ordem e a semântica das gravações operacionais. O MIPD precisa preservar esses destinos, acrescentar detalhes próprios e armazenar a imagem em bucket privado. O valor solicitado para `field_operations.source` é deliberadamente `mpid`, enquanto o código do tipo de operação será `mipd`.

## Goals / Non-Goals

**Goals:**

- Adicionar MIPD à arquitetura e à navegação existentes, sem introduzir uma estrutura paralela incompatível.
- Reutilizar a implementação cartográfica da Inspeção de modo que estilos, limites de renderização, localização e comportamento permaneçam iguais.
- Registrar uma praga ou doença e uma ou mais partes por planta, com foto opcional, inteiramente offline.
- Permitir sincronização individual e em lote com upload repetível e RPC idempotente.
- Reproduzir os efeitos operacionais da inspeção em `field_operations`, `plant_operation_history`, `plant_occurrences` e `plant_occurrence_events`, mantendo os dados específicos do MIPD normalizados e auditáveis.
- Entregar migration, políticas, contratos e documentação suficientes para implantação segura.

**Non-Goals:**

- Diagnosticar automaticamente pragas ou doenças a partir da foto.
- Capturar várias fotos por marcação, importar imagens da galeria ou editar imagens.
- Alterar as regras de negócio da Inspeção além do cache completo por categoria e da atualização explícita compartilhada.
- Sincronizar fotos em segundo plano sem uma ação do usuário ou construir um painel web de consulta.
- Tornar as imagens públicas ou armazenar binários no Postgres.

## Decisions

### 1. Criar uma vertical MIPD própria e reutilizar primitivas cartográficas

O MIPD será implementado dentro de `lib/features/operations` seguindo as camadas atuais: modelos de domínio, database/local store/remote data source/repository, view model, view e widgets. A composição será ligada em `AppDependencies`, `operation_definition.dart` e `operations_view.dart`.

Os elementos cartográficos estáveis da Inspeção — configuração do mapa, cores, construção e agrupamento de marcadores, câmera, localização e limites de processamento — serão extraídos ou expostos como componentes/serviços compartilhados. Inspeção e MIPD os consumirão com a mesma configuração. A view model do MIPD não dependerá da view model da Inspeção; somente as primitivas sem estado específico serão compartilhadas.

Essa opção evita a divergência inevitável de copiar a tela inteira e mantém filas e regras de edição independentes. Compartilhar a view model completa foi descartado porque ocorrências, validação, foto e estados de sincronização têm ciclos diferentes.

### 2. Armazenar um catálogo completo e aplicar filtros por consumidor

O modelo e a tabela SQLite de `occurrence_types` ganharão `category`. A origem compartilhada buscará `id`, `name`, `code` e `category` para todos os registros. A Inspeção derivará `category != 'PEST_DISEASE'`; o MIPD derivará `category == 'PEST_DISEASE'`.

A migração local invalidará ou atualizará o snapshot antigo que não possui categoria, forçando uma inicialização completa na primeira utilização. Um catálogo vazio confirmado continua sendo um cache válido; a interface MIPD explicará que não há pragas/doenças e oferecerá a atualização explícita.

Filtrar na origem remota separadamente foi descartado porque produziria dois caches com a mesma identidade lógica e permitiria que uma tela sobrescrevesse os dados da outra.

### 3. Unificar Carregar Plantas como atualização explícita completa

O comando Carregar Plantas, acionado pela Inspeção ou pelo MIPD, chamará uma rotina compartilhada de atualização coordenada para `farm`, `zones`, `regions`, `plants`, `occurrence_types` e ocorrências abertas necessárias. Cada conjunto será preparado em staging e a nova revisão somente será publicada quando todas as leituras e validações terminarem. Falhas preservam o snapshot anterior e as filas locais.

As telas continuam consumindo o cache ao abrir; não haverá atualização automática. A rotina completa resolve tanto a descoberta de novas categorias quanto o problema de dados de referência antigos permanecerem indefinidamente em cache.

### 4. Manter a marcação e a foto em armazenamento local durável

Uma tabela SQLite `local_mipd_markings` armazenará, no mínimo: `local_id`, `plant_id`, `occurrence_type_id`, partes em representação JSON canônica, `observed_at`, `local_photo_path`, `remote_photo_path`, estado (`pending`, `syncing`, `error`, `synced`), última mensagem de erro, identificadores remotos e timestamps. `local_id` será gerado uma vez e nunca mudará durante retries.

O arquivo retornado pela câmera será copiado para um diretório gerenciado pelo aplicativo antes da confirmação no SQLite. Se a cópia ou a transação local falhar, o modal não fecha e o item não aparece como salvo. Na inicialização, itens deixados em `syncing` voltam a um estado recuperável. As partes serão validadas no domínio e no banco remoto contra Folha, Ramo, Tronco, Raiz e Fruto.

Será usado um pacote Flutter maduro de captura por câmera, com as declarações de permissão exigidas por Android e iOS. A escolha final do pacote deve privilegiar suporte atual, captura direta e compatibilidade com as versões já fixadas no projeto.

### 5. Fazer upload antes da RPC com chave determinística

O bucket privado será `mipd-plant-photos`. O caminho do objeto seguirá `{auth.uid}/{device_id}/{local_id}.{ext}`, com tipo e extensão normalizados. O cliente autenticado fará upload/upsert e persistirá `remote_photo_path` localmente antes de chamar a RPC. Uma falha no upload deixa o item pendente/erro e não inicia a mutação no banco.

O caminho determinístico torna retries idempotentes. As políticas de `storage.objects` permitirão `select`, `insert`, `update` e `delete` somente ao proprietário autenticado e ao primeiro segmento igual a `auth.uid()`. O bucket continuará privado, com limite de tamanho e tipos MIME de imagem definidos na migration. As tabelas internas de Storage não serão modificadas diretamente; apenas o bucket e suas políticas serão configurados por SQL, e os objetos serão enviados pela API.

Não é possível incluir o upload na transação Postgres. Por isso, um lote que falhe depois do upload pode deixar um objeto ainda não referenciado. O mesmo caminho será reutilizado na próxima tentativa; uma rotina de limpeza automática de órfãos fica fora do escopo inicial.

### 6. Modelar detalhes MIPD separadamente e uma operação por marcação

A migration criará `public.mipd_markings`, vinculada a `field_operations`, `plants`, `occurrence_types` e à ocorrência consolidada. A tabela conterá `plant_parts text[]`, `photo_object_path`, `device_id`, `local_id` e timestamps. Haverá unicidade para a operação e para `(device_id, local_id)`, índices nas chaves estrangeiras consultadas e constraints que exijam ao menos uma parte e aceitem apenas os cinco valores canônicos.

Cada marcação local corresponde a um `field_operations`. Isso mantém iguais as semânticas de sincronizar um item e sincronizar todos, simplifica a idempotência e permite auditoria por observação. A operação usará o tipo semeado com código `mipd`, `source = 'mpid'` e `target_occurrence_type_id` escolhido.

Um único `field_operations` para todo o lote foi descartado porque acoplaria marcações independentes, tornaria a reconciliação parcial ambígua e dificultaria a ligação de foto e partes à observação correta.

### 7. Criar a RPC autenticada `sync_mipd_markings`

A assinatura será `public.sync_mipd_markings(p_payload jsonb)`. O contrato terá `deviceId` e `markings[]`; cada item conterá `localMarkingId`, `plantId`, `occurrenceTypeId`, `plantParts`, `observedAt` e `photoObjectPath` opcional. O retorno trará o identificador local e os IDs de operação, ocorrência e detalhe MIPD, além do resultado idempotente.

A RPC validará autenticação, formato, datas, conjunto e não-vazio de partes, existência da planta, categoria `PEST_DISEASE`, tipo de operação e, quando houver foto, prefixo pertencente ao usuário. Para cada item, fará upsert idempotente por `(device_id, local_id)`, registrará `plant_operation_history`, criará ou atualizará a ocorrência aberta segundo as regras de `sync_manual_inspection_v2`, gravará o evento de inclusão/atualização e inserirá/reutilizará `mipd_markings`. Uma repetição deverá devolver os mesmos IDs sem duplicar efeitos.

O lote de banco será atômico em uma única chamada. O cliente poderá enviar um item para sincronização individual ou vários para Sincronizar todas. O aplicativo só marcará itens como sincronizados após conciliar toda a resposta; erro transacional preserva a fila.

A função será executável apenas por `authenticated`, com `PUBLIC` e `anon` revogados. A implementação deverá escolher `security invoker` quando as políticas existentes suportarem todas as gravações; se o padrão do projeto exigir `security definer`, deverá fixar `search_path`, validar `auth.uid()` explicitamente e restringir grants. A migration concederá explicitamente os privilégios necessários, sem depender de exposição automática futura do Data API.

### 8. Versionar backend e documentação como parte da entrega

A implementação gerará uma migration Supabase pelo fluxo do projeto, contendo seed idempotente do tipo `mipd`, tabela, constraints, índices, RLS/grants, bucket privado, políticas e RPC. A migration será aplicável antes da versão móvel e será acompanhada por validações SQL de idempotência, autorização e rollback seguro.

`database.md` será atualizado no catálogo de RPCs, no item 20 com **Processo Mobile: MIPD**, no item 25 com a nova função e no SQL consolidado. O documento explicará `mipd` versus `mpid`, payload/retorno, ordem de upload, tabelas afetadas, política de ocorrência aberta, Storage e permissões.

## Risks / Trade-offs

- **Paridade visual pode regredir ao extrair componentes do mapa.** Mitigação: caracterizar a Inspeção com testes de widget/golden antes da extração e executar os mesmos cenários nas duas telas.
- **Atualizar todos os conjuntos aumenta tempo e tráfego de Carregar Plantas.** Mitigação: operações single-flight, paginação existente, staging atômico, progresso visível e manutenção do snapshot anterior durante a carga.
- **Uma atualização de catálogo invalida o formato SQLite antigo.** Mitigação: migration local versionada, detecção explícita de snapshot sem categoria e teste de upgrade com dados pendentes preservados.
- **Upload e banco não compartilham transação.** Mitigação: caminho determinístico, persistência do caminho remoto, retry seguro e documentação de objetos órfãos possíveis.
- **Um lote atômico faz um item inválido impedir os demais.** Mitigação: validação local antes do envio, erro por identificador quando possível e opção de sincronizar individualmente para isolar o problema.
- **RLS ou grants incompletos podem bloquear produção; permissões amplas podem vazar fotos.** Mitigação: testes com dois usuários, revogação explícita de `PUBLIC`/`anon`, prefixo por `auth.uid()` e revisão de advisors após aplicar a migration.
- **Fotos podem consumir espaço e dados móveis.** Mitigação: limite de tamanho/MIME no bucket, compressão normalizada no cliente e feedback separado de upload.

## Migration Plan

1. Caracterizar o comportamento atual do mapa, do cache e da Inspeção com testes antes da refatoração compartilhada.
2. Adicionar a dependência de câmera, permissões de plataforma e migration SQLite para categoria e fila MIPD, preservando filas existentes.
3. Extrair as primitivas do mapa, migrar a Inspeção para consumi-las e comprovar que aparência, renderização e interação não mudaram.
4. Implementar a vertical MIPD e a atualização completa compartilhada atrás do novo card/rota.
5. Gerar e revisar a migration Supabase; aplicar primeiro em ambiente de validação, testar RPC, RLS e Storage com usuários distintos e executar os advisors disponíveis.
6. Atualizar `database.md` e publicar o backend antes de distribuir a versão móvel que chama a RPC.
7. Validar offline, reinício, permissões de câmera, upload interrompido, retry, sincronização individual/em lote e volumes reais do mapa.

Em rollback do aplicativo, o card/rota MIPD pode ser removido sem afetar Inspeção ou Pulverização. No banco, primeiro serão revogados grants e removidas a RPC e políticas. A tabela deve ser preservada enquanto contiver dados; o bucket só poderá ser removido após confirmar que está vazio ou que os objetos foram exportados. O seed do tipo de operação não deve ser apagado se já houver referências.

