## Why

A opção Operações → Inspeção atualmente abre apenas uma tela reservada. O trabalho de campo precisa permitir identificar plantas no mapa, registrar ocorrências sem perder dados quando faltar conexão e consolidar as alterações em uma operação rastreável no Supabase.

## What Changes

- Substituir a tela reservada por um mapa com posição do usuário, mantendo a navegação inferior do aplicativo e o retorno para Operações.
- Apresentar um card entre mapa e navegação com três ações: carregar plantas de `plants` com `non_existent = false`, abrir o catálogo de `occurrence_types` por `name` e imprimir somente o `code` selecionado, e consultar todas as inspeções armazenadas no SQLite.
- Abrir o editor ao tocar em uma planta individual. Exibir todas as ocorrências com indicadores circulares independentes, permitindo marcar várias e desmarcar por novo toque, conforme confirmação do usuário.
- Persistir cada alteração localmente. O botão fixo **Atualizar**, no editor, finaliza uma inspeção com todas as plantas alteradas naquela sessão e tenta sincronizá-la, conforme confirmação do usuário.
- Manter inspeções pendentes em caso de falta de internet, permitir reenvio pela lista local e recuperar rascunhos após reabertura do app.
- Reutilizar `sync_manual_inspection(p_payload)` conforme a versão enviada pelo usuário, preservando `field_operations`, `plant_operation_history`, `plant_occurrences` e também `plant_occurrence_events`. Se a conferência do banco demonstrar necessidade de adaptação, criar uma RPC com novo nome via MCP Supabase durante a implementação, preservando a existente.

## Capabilities

### New Capabilities

- `manual-inspection`: mapa, localização, carregamento de plantas, catálogo de ocorrências e editor multisseleção com ação fixa de atualização.
- `inspection-offline-sync`: persistência SQLite, recuperação, lista local e sincronização idempotente de uma inspeção com múltiplas plantas.

### Modified Capabilities

- `operations-menu`: abrir a inspeção funcional dentro da navegação principal e preservar retorno e rascunhos.
- `main-navigation`: manter a barra inferior também na Inspeção, com Operações selecionado.

## Impact

- Flutter: `lib/features/operations/`, `lib/app/widgets/main_shell.dart` e `lib/core/di/`; novas camadas de dados/domínio/apresentação seguindo MVVM, `ChangeNotifier`, repositórios e injeção existentes.
- Reutilizar `google_maps_flutter`, `LocationService`/Geolocator, `supabase_flutter` e o tema Material 3. Adicionar dependências SQLite e identificação local conforme compatibilidade do projeto; sem trocar a arquitetura ou o provedor de mapa.
- Novos testes de domínio, repositório, SQLite, widgets e fluxo móvel; atualizar os testes que esperam o placeholder.
- `database.md` é referência de domínio, mas contém versões divergentes da RPC e exemplos legados de React Native. A versão fornecida na solicitação prevalece para o contrato planejado; o schema implantado ainda deverá ser conferido via MCP, indisponível nesta sessão.
- Fora do escopo: filtros por zona/variedade, aplicação em massa da ocorrência selecionada no segundo botão, seleção automática da planta mais próxima, trilhas GPS, novas telas de autenticação, sincronização em background e garantia de mapas-base offline. Nenhuma modificação remota ou implementação faz parte desta etapa de proposta.
