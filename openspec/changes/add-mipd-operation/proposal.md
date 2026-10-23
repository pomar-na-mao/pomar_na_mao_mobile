## Why

O aplicativo ainda não oferece um fluxo de campo dedicado ao Manejo Integrado de Pragas e Doenças (MIPD), capaz de registrar evidências por planta, funcionar offline e sincronizar os apontamentos com rastreabilidade. A nova operação reutiliza a experiência cartográfica já validada na Inspeção e separa os registros fitossanitários das ocorrências estruturais, ambientais e antrópicas.

## What Changes

- Adicionar o card habilitado **MIPD (Manejo Integrado de Pragas e Doenças)** em Operações, imediatamente abaixo de Pulverização, com navegação para uma tela própria.
- Criar uma tela MIPD com o mesmo mapa, localização do usuário, cores, marcadores, agrupamento, estratégia de renderização e carregamento explícito de plantas usados pela Inspeção.
- Adicionar o card inferior com as ações **Carregar Plantas** e **Marcações salvas**.
- Ao tocar em uma planta, abrir um editor com seleção única de ocorrência cuja `occurrence_types.category = 'PEST_DISEASE'`, seleção múltipla obrigatória das partes Folha, Ramo, Tronco, Raiz e Fruto, e captura opcional de uma foto pela câmera com pré-visualização no card pontilhado.
- Persistir cada marcação e, quando existente, sua foto localmente antes de qualquer envio, permitindo listar, recuperar e sincronizar um item ou toda a fila.
- Adicionar sincronização idempotente por uma nova RPC `sync_mipd_markings(p_payload jsonb)`, criando `field_operations` com tipo `mipd` e `source = 'mpid'` e gravando os mesmos destinos operacionais da inspeção manual: `plant_operation_history`, `plant_occurrences` e `plant_occurrence_events`.
- Adicionar persistência estruturada dos dados exclusivos do MIPD (partes da planta e caminho da foto) vinculada à operação, planta e ocorrência, além de bucket privado no Supabase Storage para as imagens.
- Entregar ao final da implementação uma migration SQL idempotente com tabela/índices/constraints necessários, seed do tipo de operação, RPC, grants e bucket/políticas de Storage.
- Atualizar `database.md` com o contrato, payload, retorno e comportamento da RPC; incluir **Processo Mobile: MIPD** no item 20 e a nova RPC no item 25 e no script SQL consolidado.

## Capabilities

### New Capabilities

- `mipd-operation`: Experiência MIPD no mapa, seleção fitossanitária por planta, partes afetadas, captura opcional de foto e consulta das marcações salvas.
- `mipd-offline-sync`: Persistência SQLite, fila individual/em lote, upload seguro da foto, sincronização idempotente via RPC e armazenamento remoto estruturado.

### Modified Capabilities

- `operations-menu`: Adiciona MIPD como operação habilitada e navegável logo após Pulverização.
- `local-read-cache`: Passa a disponibilizar catálogos por categoria para que Inspeção exclua e MIPD inclua exclusivamente `PEST_DISEASE`, sem duplicar o cache compartilhado de plantas.

## Impact

- **Flutter:** novos modelos, banco SQLite, local store, data source, repository, view model, tela e widgets MIPD dentro da estrutura existente de `features/operations`; reutilização dos componentes e serviços cartográficos da Inspeção; integração de câmera e gerenciamento de arquivo local.
- **Navegação/DI:** novo card, rota e dependências MIPD em `operation_definition.dart`, `operations_view.dart` e `AppDependencies`.
- **Supabase/Postgres:** nova tabela de detalhes MIPD, tipo de operação, RPC, índices, constraints, RLS/grants e bucket privado com políticas por usuário autenticado.
- **Storage:** upload anterior à RPC com caminho determinístico e retry idempotente; leitura autenticada da imagem, sem chave privilegiada no cliente.
- **Documentação:** atualização das seções 18, 20, 24/25 e do SQL consolidado de `database.md`, acompanhada da migration executável ao final da implementação.
- **Dependências e plataformas:** pacote Flutter para captura pela câmera e configurações/permissões correspondentes em Android/iOS.
