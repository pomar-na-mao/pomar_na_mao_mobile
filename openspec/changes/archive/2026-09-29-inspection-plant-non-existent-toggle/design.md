## Context

Atualmente, na inspeção manual móvel do aplicativo Pomar na Mão, o modal `PlantEditorModal` exibe a identificação da planta selecionada e a listagem de ocorrências (`OccurrenceType`), permitindo marcar e desmarcar apontamentos. O modelo `InspectionPlant` já contém o atributo `nonExistent` (mapeado de `non_existent` da tabela `plants`), mas a interface de inspeção não disponibiliza controle para alterar esse valor nem propaga essa propriedade durante o ciclo de sincronização remota via RPC `sync_manual_inspection_v2`.

A especificação de banco consolidada em `database.md` descreve a RPC `sync_manual_inspection_v2(p_payload jsonb)`, que itera sobre o array `plantsChanged`. Atualmente, essa função processa as transições em `plant_occurrences` e `plant_occurrence_events`, além do vínculo em `plant_operation_history`, mas não atualiza a existência física na tabela `plants`.

## Goals / Non-Goals

**Goals:**
- Incluir no topo de `PlantEditorModal`, imediatamente acima da listagem de ocorrências, um toggle visualmente destacado e acessível denominado "Planta Inexistente".
- Inicializar o toggle com o estado corrente da planta (`non_existent` booleano).
- Permitir ao operador alternar o toggle e habilitar a ação de salvar / atualizar mesmo se nenhuma ocorrência tiver sido alterada.
- Persistir a alteração de `nonExistent` no armazenamento local da inspeção ativa (SQLite).
- Incluir a propriedade `nonExistent` (ou `non_existent`) em cada entrada de `plantsChanged` no payload gerado para a RPC `sync_manual_inspection_v2`.
- Atualizar a função RPC `sync_manual_inspection_v2` para que, para todas as plantas do lote em `plantsChanged`, a coluna `non_existent` (e `updated_at`) da tabela `plants` seja atualizada conforme enviado no payload.
- Atualizar a documentação arquitetural em `database.md` documentando a extensão do contrato e o código SQL correspondente da RPC.

**Non-Goals:**
- Alterar o fluxo de seleção ou filtragem do mapa de inspeção.
- Modificar o contrato de apontamento de ocorrências individuais (`plant_occurrence_events`).
- Tratar exclusão permanente de linhas na tabela `plants` (o campo `non_existent` é um flag lógico).

## Decisions

### 1. Posicionamento e Comportamento na UI (`PlantEditorModal`)
- **Decisão**: Inserir um `SwitchListTile` (ou card equivalente com `Switch`) entre o cabeçalho/banner de feedback e o `ListView` de ocorrências.
- **Rótulo**: "Planta Inexistente", com subtítulo explicativo caso desejável (ex.: "Marque se a planta não existe no local").
- **Acessibilidade**: Atribuir semântica clara com anúncio de toggle/switch e estado ativo/desativado.
- **Alternativas consideradas**:
  - *Botão de ação avulso no rodapé*: Descartado, pois o rodapé já possui a ação principal "Atualizar" e a solicitação exige explicitamente no topo da tela, acima das ocorrências.

### 2. Gerenciamento de Estado no `InspectionViewModel`
- **Decisão**: Adicionar a propriedade reativa `bool _stagedNonExistent` ao ViewModel.
  - Ao executar `selectPlant(plant)`, definir `_stagedNonExistent = plant.nonExistent`.
  - Adicionar método `setStagedNonExistent(bool value)`.
  - Ajustar `hasStagedChanges` para:
    `!setEquals(_stagedOccurrenceTypeIds, _selectedPlant!.openTypeIds) || _stagedNonExistent != _selectedPlant!.nonExistent`.
  - Ao salvar (`savePlantChanges()`):
    Se `_stagedNonExistent != plant.nonExistent`, persistir o novo estado da planta no SQLite da inspeção e atualizar o snapshot em memória.
- **Alternativas consideradas**:
  - *Atualizar imediatamente no SQLite ao tocar no toggle sem confirmação*: Descartado para manter consistência com o padrão de confirmação de lote/edição da tela ao clicar em "Atualizar".

### 3. Persistência Local no SQLite (`InspectionLocalStore`)
- **Decisão**: 
  - Registrar a alteração de existência da planta associada à inspeção em andamento.
  - Garantir que a planta seja considerada alterada em `local_inspection_loaded_plants` / `local_inspections` mesmo com lista vazia de transições de ocorrências.
  - Ao compor o `payload` na finalização da inspeção, cada item de `plantsChanged` passará a conter:
    ```json
    {
      "plantId": "uuid-da-planta",
      "nonExistent": true, // ou false
      "changes": [...]
    }
    ```
- **Alternativas consideradas**:
  - *Criar um pseudo-tipo de ocorrência "planta_inexistente"*: Descartado, pois `non_existent` é uma propriedade de primeira classe na tabela `plants` e não um evento/ocorrência diagnóstica.

### 4. Ajuste na RPC `sync_manual_inspection_v2` e `database.md`
- **Decisão**: No loop `for v_plant in select value from jsonb_array_elements(...)` da RPC, adicionar a verificação:
  ```sql
  if v_plant ? 'nonExistent' or v_plant ? 'non_existent' then
    update public.plants
    set
      non_existent = coalesce(
        (v_plant->>'nonExistent')::boolean,
        (v_plant->>'non_existent')::boolean
      ),
      updated_at = now()
    where id = v_plant_id;
  end if;
  ```
- Atualizar a seção de RPCs em `database.md` refletindo este novo comportamento e preservando compatibilidade retroativa (caso o campo venha nulo/omitido em payloads antigos, a coluna não é alterada).

## Risks / Trade-offs

- **[Plantas com `non_existent = true` desaparecendo do mapa]** → No carregamento inicial de inspeção, o app filtra plantas ativas. Se o operador marcar como inexistente e sincronizar, a planta deixará de ser elegível em inspeções subsequentes. Isso é o comportamento esperado para plantas inexistentes no pomar.
- **[Conflito de sincronização offline]** → Se dois dispositivos alterarem a mesma planta offline, a última sincronização recebida pela RPC atualizará o valor com base em `now()`.
- **[Retrocompatibilidade do payload]** → O uso de `if v_plant ? 'nonExistent' or v_plant ? 'non_existent'` na RPC garante que payloads que não enviem esse campo continuem sendo processados sem erro.

## Migration Plan

1. Atualizar a especificação e o código SQL em `database.md`.
2. Executar/implantar a definição atualizada da RPC `sync_manual_inspection_v2` no Supabase via MCP/SQL.
3. Atualizar modelos, repositório local e serialização do payload no aplicativo móvel.
4. Atualizar o ViewModel e a interface `PlantEditorModal`.
5. Validar testes unitários e de integração de fluxo local e remoto.
