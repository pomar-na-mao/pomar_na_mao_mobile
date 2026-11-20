## Why

O aplicativo ainda não dispõe de uma rotina rápida em campo para registrar a Previsão de Safra por estimativa visual durante o deslocamento no pomar. Adicionar a operação **Previsão de Safra** em **Rotina do pomar** permite ao operador caminhar ou percorrer os talhões acompanhando sua posição direcionada e rota no mapa, classificar rapidamente o potencial produtivo com um toque (`N`, `P`, `M`, `G`, `GG`) de forma offline, revisar/editar/excluir registros locais e sincronizá-los vinculando cada ponto à planta ativa mais próxima no Supabase.

## What Changes

- Adicionar o card habilitado **Previsão de Safra** na seção **Rotina do pomar** da tela **Operações**, posicionado imediatamente depois de **Estoque**, com navegação para uma tela própria.
- Criar a tela de **Previsão de Safra** inspirada na estrutura inicial do MIPD, contendo o mapa ocupando a área principal e, na base, a barra com 5 botões circulares na mesma linha (`N`, `P`, `M`, `G`, `GG` — Nenhuma, Pequena, Média, Grande e Muito Grande) posicionada entre o mapa e o card inferior com os botões **Carregar plantas** e **Marcações salvas**.
- Exibir no mapa as plantas carregadas do pomar, o marcador da posição atual do usuário com indicação de direção (heading/course) e a polilinha da rota percorrida (como na Pulverização).
- Atualizar a câmera acompanhando a posição do usuário inicialmente, mas suspender o reposicionamento automático ao detectar interação manual/zoom no mapa (como em **Operações -> Rotina do pomar -> Ocorrências**), permitindo visualizar uma área grande sem que o mapa volte sozinho para a posição do usuário.
- Ao clicar em qualquer um dos 5 botões circulares (`N`, `P`, `M`, `G` ou `GG`), gravar localmente no SQLite um registro contendo a `latitude` e `longitude` da posição no momento do clique, a classificação (`classification`: `N`, `P`, `M`, `G` ou `GG`) e a data/hora do registro (`created_at`), ordenando a listagem local da marcação mais nova para a mais antiga (no topo de **Marcações salvas**).
- No modal **Marcações salvas**, permitir visualizar a lista ordenada da mais recente para a mais antiga, alterar a classificação (`N`, `P`, `M`, `G`, `GG`) de um registro existente, excluir um registro local, sincronizar individualmente cada registro e sincronizar todos os pendentes.
- Criar uma migration SQL no diretório `supabase/migrations` (sem executar alterações diretas no Supabase via MCP) que define a nova tabela remota de previsão de safra (`public.harvest_forecasts`) com as colunas `id` (uuid único gerado na criação), `plant_id` (uuid único da planta mais próxima encontrada), `zone_id` (uuid `plants.zone_id` da planta encontrada), `classification` (`N`, `P`, `M`, `G`, `GG`), `latitude`, `longitude`, `created_at` (data/hora da marcação recebida do dispositivo) e `updated_at` (gerada como data/hora atual pela RPC), além da RPC transacional que localiza item a item a planta mais próxima pelas coordenadas (`latitude`, `longitude`) e faz `UPSERT` por `plant_id` (substituindo o registro atual caso `plant_id` já exista).
- Atualizar `database.md` nos itens **20** e **25** documentando o novo processo mobile, a tabela e a RPC.

## Capabilities

### New Capabilities
- `harvest-forecast-operation`: Tela de Previsão de Safra com mapa, plantas, marcador direcional do usuário, rastro de rota, controle de câmera que respeita zoom/pan manual sem reposicionar automaticamente, barra de 5 botões circulares (`N`, `P`, `M`, `G`, `GG`), card inferior (`Carregar plantas` e `Marcações salvas`) e gerenciamento local (edição de classificação e exclusão) na lista de Marcações Salvas.
- `harvest-forecast-offline-sync`: Armazenamento SQLite offline das marcações de previsão de safra, sincronização individual e em lote, resolução espacial da planta mais próxima na RPC do Supabase e persistência com unicidade e substituição (`UPSERT`) por `plant_id`.

### Modified Capabilities
- `operations-menu`: Inclusão do card habilitado **Previsão de Safra** no módulo **Rotina do pomar**, imediatamente após o card **Estoque**.

## Impact

- **Flutter/Dart (`lib/features/operations` e `lib/core/di`):** novos modelos de domínio, database/local store SQLite, remote data source, repository, view model, view e modal de marcações salvas para Previsão de Safra; registro em `operation_definition.dart`, `operations_view.dart`, `main_shell.dart` e `AppDependencies`.
- **Supabase (`supabase/migrations`):** novo arquivo de migration SQL contendo a tabela `public.harvest_forecasts`, constraints (`UNIQUE (plant_id)`, check de `classification IN ('N', 'P', 'M', 'G', 'GG')`), índices, políticas RLS/grants e RPC de sincronização com busca espacial PostGIS (`<->` sobre `plants.location`) e `ON CONFLICT (plant_id) DO UPDATE`. Nenhuma alteração será aplicada via MCP no Supabase.
- **Documentação (`database.md`):** adição da subseção do processo mobile de Previsão de Safra no item 20 e da especificação executável da tabela e RPC no item 25.
