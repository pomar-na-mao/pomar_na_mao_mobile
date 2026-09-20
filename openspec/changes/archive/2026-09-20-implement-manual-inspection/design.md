## Context

Ver `proposal.md` para motivação e escopo. A tela atual é `lib/features/operations/presentation/inspection_view.dart`, aberta por uma rota sobre o `MainShell`, o que oculta a barra inferior. O projeto utiliza Material 3, cor-semente `#3C6E47`, fundo de Operações `#F4F7F2`, cards arredondados, `ChangeNotifier`, repositórios por feature e DI em `AppDependencies`/`AppScope`. Não há dependência SQLite no `pubspec.yaml` atual.

`FarmMapView` já utiliza Google Maps, marcadores e agrupamento. `LocationService` oferece posição atual e stream com estados de erro. A consulta de plantas da Fazenda é paginada mas não filtra `non_existent`: o filtro da inspeção não deve modificar o comportamento da Fazenda.

O usuário confirmou múltiplas ocorrências independentes e que Atualizar, dentro do modal, finaliza todas as alterações da inspeção e tenta enviá-las. O catálogo do segundo botão apenas imprime o código escolhido.

### Conferência da RPC e do histórico

A versão enviada corresponde à função da seção 24.9 de `database.md` (início na linha 6450), cujo contrato está na seção 24.4. Ela escreve nas quatro tabelas:

| Destino | Efeito |
| --- | --- |
| `field_operations` | Upsert por `(device_id, local_id)`, operação `manual_inspection` |
| `plant_operation_history` | Um vínculo por planta/operação, com `uq_plant_operation` |
| `plant_occurrences` | Criar, atualizar ou resolver a ocorrência aberta |
| `plant_occurrence_events` | Evento `added`, `updated` ou `removed`, ligado à operação atual |

Os três INSERTs de eventos estão nas linhas 6644, 6706 e 6771 do documento consultado. A função guarda snapshots, ordena mudanças por `changedAt` e `localChangeId`, ignora eventos já presentes pelo par dispositivo/mudança e não troca a operação de origem ao atualizar/resolver uma ocorrência. Remover uma ocorrência não aberta não gera evento. Os contadores medem alterações aplicadas naquela chamada; um retry pode retornar contadores zero e ainda ser sucesso.

A seção 24 identifica esse contrato como canônico. O bloco posterior iniciado na linha 8802 é divergente: não insere eventos, usa `removed` no estado da ocorrência e não faz o mesmo upsert da operação. Não utilizá-lo como base. A leitura do arquivo não confirma qual função está implantada. A tentativa de acessar MCP retornou: `failed to refresh OAuth tokens ... Failed to parse server response`; portanto a verificação remota é uma tarefa explícita anterior à integração, não uma validação já realizada.

## Goals / Non-Goals

**Goals:** separar apresentação de persistência, garantir durabilidade antes da rede, preservar auditoria e suportar retries sem duplicação, mantendo o padrão visual e arquitetural atual.

**Non-Goals:** trocar estado global ou roteador do app, copiar os fluxos React Native do documento, introduzir autenticação nova, garantir resolução de conflitos entre dispositivos, baixar mapas-base para offline ou alterar tabelas remotas sem necessidade demonstrada.

## Decisions

### 1. Feature MVVM e navegação interna de Operações

Manter Inspeção em `features/operations`, com modelos imutáveis em `domain`, datasources SQLite/Supabase e repositório em `data`, ViewModel e widgets em `presentation`. Registrar dependências no container atual. Reutilizar `LocationService` e componentes de mapa que possam ser extraídos sem mudar a Fazenda. Evitar `freezed`, Provider ou outro gerador somente para esta feature: as classes e a DI manuais já são o padrão.

Usar um Navigator interno ao destino Operações do `IndexedStack`. O shell continua sendo o único dono da barra inferior. O retorno fecha modal, depois Inspeção, depois segue o comportamento do shell; alternar abas preserva a rota interna. Suspender o stream de localização quando a inspeção estiver invisível e cancelá-lo ao encerrar seu ciclo de vida. Não empilhar uma segunda barra na rota raiz.

### 2. Layout e interação

Aplicar as diretrizes de `ui-ux-pro-max`, layout responsivo Flutter e testes Dart lidas nesta proposta. O script de busca da skill não pôde executar por falta de Python; as decisões usam suas orientações disponíveis e o tema do repositório.

Composição da tela:

```text
AppBar: ← Inspeção
Mapa (ocupa o espaço restante; posição, plantas, recenter)
Card: Carregar plantas | Ocorrências | Inspeções salvas
NavigationBar: Inventário | Fazenda | Operações | Sobre
```

Mapa em `Expanded`; card em fluxo normal, com margens de 16, cantos 24 e espaçamento 8–16. Usar ícones Material e textos, `ColorScheme`, `LayoutBuilder`, `SafeArea` e rearranjo vertical das ações quando largura/texto exigirem. Evitar altura fixa que corte texto ampliado; testar também paisagem curta.

Editor em bottom sheet alto, com cabeçalho identificando a planta, lista em `Expanded/ListView.builder` e rodapé fixo contendo Atualizar e o resumo “N plantas alteradas”. Fechar o modal mantém o rascunho salvo e permite editar outras plantas antes da finalização. Indicadores circulares terão semântica de checkbox/multisseleção, não `RadioGroup` exclusivo. Mensagens de gravação e sincronização distinguem “Salvo no dispositivo” de “Sincronizado”. Durante gravação local, bloquear ações dependentes até confirmar ou reverter o estado; durante envio, impedir nova finalização do lote.

Não impor um nível artificial de zoom para editar: tocar em marcador individual abre o editor; clusters aproximam o mapa até permitir selecionar a planta. Atualizações GPS movem a indicação, mas não forçam recentralização após gesto manual.

### 3. Consulta própria, paginada e cache completo

Implementar datasource de inspeção com `.from('plants')`, `.eq('non_existent', false)`, ordenação estável por `id` e paginação. Consultar `occurrence_types(id,name,code)` ordenado por nome e ocorrências `open` das plantas, em lotes/páginas, evitando uma chamada por marcador. Validar coordenadas; informar registros não renderizáveis sem posicioná-los em zero.

Publicar um novo snapshot local somente após completar plantas, catálogo e ocorrências. Não usar falha de consulta como lista vazia. Na ausência de rede, permitir o último conjunto completo já salvo; sem catálogo ou estado conhecido da planta, bloquear edição e explicar a necessidade de carregamento. Recarregar mantém IDs da inspeção ativa e sobrepõe as alterações locais ao snapshot remoto; plantas com mudanças locais são retidas para auditoria mesmo se deixarem de ser elegíveis para o mapa.

O segundo modal utiliza o catálogo/cache, com `debugPrint(code)` ou saída diagnóstica injetável para teste. Não define `occurrenceTypeId` do payload. Sem filtro de zona ou ocorrência, `zoneId` e `occurrenceTypeId` ficam nulos, inclusive para inspeções que abrangem várias zonas.

### 4. SQLite como fonte durável

Adicionar `sqflite`, `path` e geração UUID, escolhendo versões compatíveis no apply e mantendo lockfile. Para testes de persistência no Windows, usar backend SQLite de teste compatível, como `sqflite_common_ffi`, sem exigir banco real Supabase. Não usar SharedPreferences como substituto de SQLite.

Modelo local inspirado na seção 20.2, adaptado ao Flutter:

| Estrutura | Responsabilidade |
| --- | --- |
| `local_inspections` | ID, início/fim, estado, sync status, contagens, erro, ID remoto e payload finalizado |
| `local_inspection_loaded_plants` | Snapshot por `(inspection_local_id, plant_id)`, coordenadas e ocorrências-base |
| `local_inspection_changes` | Diário por ID, planta/tipo, add/remove, sequência, instante UTC e contexto GPS opcional |
| Catálogo local de tipos | ID, nome e código para edição offline |
| Metadados da instalação | `deviceId` UUID persistente, versão do banco e projeto Supabase associado |

Isolar o arquivo/cache pelo projeto configurado para não enviar UUIDs de um projeto a outro. Criar migrations locais versionadas, transações, chaves estrangeiras e índices de inspeção/planta/estado. Um único rascunho ativo por projeto; criado ao concluir o primeiro carregamento e retomado nas próximas aberturas. Carregamentos sem edição não geram operações remotas.

Persistir cada toggle como transição, preservando também alternâncias que terminam no estado inicial, pois são observações auditáveis. Somente plantas com transições entram em `plantsChanged`. Registrar uma sequência local e `changedAt` UTC estritamente crescente por inspeção, inclusive após reinício, para que o desempate aleatório de UUID não inverta ações feitas no mesmo instante. Capturar posição/precisão/distância se disponíveis; nunca exigir GPS ou fabricar valores para salvar.

Ao finalizar: aguardar gravações, construir o payload a partir do SQLite, fixar `finishedAt`, congelar payload e atualizar estado em uma transação. Alterações posteriores iniciam novo lote com snapshot efetivo que inclui alterações pendentes anteriores. Reabrir consulta remota nunca sobrepõe esse estado local.

### 5. Envio transacional e recuperação

Fluxo: `in_progress/pending` → `finished/pending` → `finished/syncing` → `synced/synced`; em falha, `finished/error`, preservando o mesmo payload. Um estado `syncing` encontrado na inicialização volta a ser reenviável. Uma transação local grava sucesso, ID remoto, timestamp e estados das mudanças após resposta válida; falha no commit local exige retry remoto com os mesmos IDs.

Enviar via `supabase.rpc('sync_manual_inspection', params: {'p_payload': payload})`. Desserializar uma linha contendo `field_operation_id`, `created_occurrences_count`, `updated_occurrences_count` e `resolved_occurrences_count`. Nunca usar contadores maiores que zero como condição de sucesso. Campos opcionais de snapshots devem ser omitidos se não conhecidos: JSON `null` explícito não aciona necessariamente o fallback SQL `coalesce`.

Uma fila por projeto serializa lotes por finalização; Atualizar e o botão Sincronizar da lista acionam a fila. Parar em erro antes de lotes posteriores para evitar uma remoção chegar antes da adição anterior. Não há worker em background neste escopo. Timeout, perda de resposta e offline resultam em pendência recuperável. Manter inspeções sincronizadas no SQLite e recarregar o estado remoto quando possível sem apagar edições posteriores.

### 6. Contrato remoto: reutilizar primeiro, nova RPC somente se necessária

Durante apply, verificar via MCP o projeto `uxschjkypkkzprbwuhxm` e a definição real com introspecção de função, retorno, constraints, índices e permissões. Verificar também `operation_types.code = 'manual_inspection'`, acesso de leitura do app às plantas/tipos/ocorrências e `updated_at` usado na RPC. Não executar o `database.md` inteiro: contém exemplos divergentes e blocos destrutivos.

Reutilizar a função auditável se estiver compatível. Se não estiver, criar `sync_manual_inspection_v2` (ou outro novo nome livre) via MCP, manter a anterior e documentar/migrar a nova função no repositório. Preservar os quatro destinos, transação e identidades. Conferir índice único parcial `(device_id, local_id)` em operações, `uq_plant_operation` e `(device_id, local_change_id)` em eventos; `ON CONFLICT` depende desses objetos.

Preservar o modelo de acesso documentado do app, que utiliza chave pública e admite operação sem login. Revisar acesso da RPC `SECURITY DEFINER`, schema qualificado, `search_path` vazio, validação de payload e grants explicitamente; não resolver erros incluindo service role no cliente nem ampliar acesso por suposição. O cliente não escreve diretamente em eventos. Se o modelo remoto não permitir o fluxo atual, registrar o bloqueio concreto de acesso antes de publicar integração.

Retries sequenciais com os mesmos IDs são cobertos pelo contrato, mas isso não equivale a resolver concorrência entre dispositivos. Uma inspeção offline pode partir de snapshot antigo; manter a semântica remota fornecida: adicionar sobre aberta atualiza; remover sem aberta é no-op. Testar esses comportamentos explicitamente.

Referências técnicas consultadas: [RPC em Dart](https://supabase.com/docs/reference/dart/rpc), além do código local e `database.md`, seções 20.2 e 24. O formato de chamada aceita parâmetros nomeados, permitindo enviar `p_payload` sem dividir a operação em gravações REST independentes.

## Risks / Trade-offs

- [MCP falha no refresh OAuth] → Conferência/deploy remoto dependem de reconexão; não tratar análise documental como prova do banco implantado.
- [Catálogo/plantas extensos] → Paginação, consultas em lotes, renderização agrupada e teste acima de 1.000 plantas.
- [Mapas-base não disponíveis offline] → Dados de inspeção continuam persistidos, mas tiles dependem do SDK/cache; não prometer download offline.
- [Snapshots antigos ou múltiplos dispositivos] → Preservar semântica da RPC e auditabilidade, fila ordenada por instalação e testes de divergência; merge distribuído não faz parte desta mudança.
- [Perda de energia, disco cheio e resposta perdida] → Transações, IDs estáveis, lote imutável e testes de recuperação; não mostrar sucesso antes do commit local/remoto correspondente.
- [Rodapé e navegação disputam altura] → Layout por constraints, lista interna rolável, SafeArea e testes em tela compacta, paisagem e texto ampliado.
- [Diário de toggles aumenta eventos] → Transições são intencionais e auditáveis; não gerar evento por renderização, toque sem mudança ou retry.

## Migration Plan

1. Conferir contrato remoto e requisitos de acesso pelo MCP; registrar a definição canônica sem executar scripts legados.
2. Introduzir banco SQLite versionado e serviços injetáveis; não existe banco local deste Flutter a converter, mas testes devem cobrir reabertura e migrations futuras sem perda.
3. Implementar fluxo, fila e UI; se necessária nova RPC, validá-la antes de apontar o cliente para ela. Publicar alteração SQL por MCP somente na fase de apply.
4. Executar testes locais e validar fluxo em dispositivo: múltiplas plantas, offline, reinício e retry após resposta perdida. Verificar quatro tabelas no ambiente de teste autorizado.
5. Para rollback do app, preservar arquivos SQLite e suas pendências. Se houver RPC nova, restaurar seleção do endpoint compatível sem apagar função antiga ou registros remotos; não aplicar downgrade destrutivo do banco local.
