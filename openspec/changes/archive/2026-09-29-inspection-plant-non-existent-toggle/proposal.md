## Why

Durante inspeções a campo, operadores precisam registrar quando uma planta cadastrada não existe mais fisicamente no talhão (morte, erradicação ou erro de cadastro), além de apontar ou resolver ocorrências. Atualmente, o modal de edição de planta permite gerenciar apenas ocorrências e não oferece controle sobre a existência física da árvore (`non_existent`). Além disso, a sincronização via `sync_manual_inspection_v2` consolida ocorrências mas não propaga a alteração de existência da planta para a tabela `plants` no Supabase.

## What Changes

- **Toggle "Planta Inexistente" no modal da planta**: Adiciona um controle toggle (`SwitchListTile` / switch acessível) posicionado no topo da tela do modal de edição da planta (`PlantEditorModal`), acima da listagem de ocorrências.
- **Inicialização do estado**: O toggle é ativado caso `non_existent` da planta seja `true` e desativado caso seja `false`.
- **Estágio e persistência local**: Alterações no toggle são mantidas em rascunho com suporte a desfazer antes de atualizar e gravadas no armazenamento local (SQLite) da inspeção em andamento, marcando a planta como alterada mesmo que nenhuma ocorrência tenha sido alterada.
- **Payload de sincronização**: O payload gerado na finalização da inspeção passa a incluir o estado `nonExistent` (ou `non_existent`) para cada planta alterada em `plantsChanged`.
- **Atualização na RPC `sync_manual_inspection_v2`**: A função no Supabase atualiza a coluna `non_existent` e `updated_at` na tabela `plants` para todas as plantas enviadas no payload da inspeção.
- **Atualização documental**: Atualização de `database.md` com a nova lógica da RPC `sync_manual_inspection_v2` refletindo a atualização da tabela `plants`.

## Capabilities

### New Capabilities
<!-- Nenhuma nova capacidade necessária; as capacidades existentes cobrem inspeção e sincronização offline. -->

### Modified Capabilities
- `manual-inspection`: Adiciona a exigência do toggle "Planta Inexistente" no topo do modal de edição de planta, refletindo o valor de `non_existent` e permitindo alternância antes de salvar/atualizar.
- `inspection-offline-sync`: Atualiza os requisitos de consolidação e envio da inspeção para persistir localmente o estado `non_existent` por planta, transmitir esse valor no payload de `sync_manual_inspection_v2` e atualizar a tabela `plants` no banco de dados, documentando a RPC em `database.md`.

## Impact

- **UI / Mobile**: `lib/features/operations/presentation/widgets/plant_editor_modal.dart`, `lib/features/operations/presentation/inspection_view_model.dart`.
- **Modelos e Repositório**: `lib/features/operations/domain/inspection_models.dart`, `lib/features/operations/data/inspection_local_store.dart`, `lib/features/operations/data/inspection_repository.dart`, `lib/features/operations/data/inspection_remote_data_source.dart`.
- **Backend / Database**: Definição da RPC `sync_manual_inspection_v2` em `database.md` e no banco Supabase para efetuar `update public.plants set non_existent = ... where id = ...`.
