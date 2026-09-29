## 1. Banco de Dados e Documentação

- [x] 1.1 Atualizar a documentação e definição SQL da RPC `sync_manual_inspection_v2` em `database.md` para incluir a atualização da coluna `non_existent` na tabela `plants` para todas as plantas enviadas em `plantsChanged`, e verificar a formatação do arquivo.
- [x] 1.2 Atualizar/implantar a definição da RPC `sync_manual_inspection_v2` no Supabase garantindo suporte aos campos `nonExistent` / `non_existent` em cada item de `plantsChanged`.

## 2. Modelos e Camada de Dados

- [x] 2.1 Atualizar `InspectionPlant` em `lib/features/operations/domain/inspection_models.dart` adicionando parâmetro opcional `nonExistent` no método `withState` e verificar consistência de serialização e desserialização.
- [x] 2.2 Atualizar `InspectionLocalStore` e `InspectionRepository` em `lib/features/operations/data/` para armazenar a alteração do flag de inexistência da planta durante a inspeção e compor `nonExistent` dentro de cada objeto de `plantsChanged` no payload gerado na finalização.
- [x] 2.3 Ajustar `InspectionRemoteDataSource.fetchPlants` em `lib/features/operations/data/inspection_remote_data_source.dart` para selecionar explicitamente a coluna `non_existent`.

## 3. Apresentação e Gerenciamento de Estado

- [x] 3.1 Adicionar controle de estado estagiado de `nonExistent` em `InspectionViewModel` (`_stagedNonExistent`, `toggleStagedNonExistent()`, atualização em `selectPlant`, ajuste na propriedade `hasStagedChanges` e inclusão em `savePlantChanges()`).
- [x] 3.2 Adicionar o toggle acessível "Planta Inexistente" no topo de `PlantEditorModal` em `lib/features/operations/presentation/widgets/plant_editor_modal.dart`, acima da lista de ocorrências, refletindo o estado estagiado e acionando o ViewModel.

## 4. Testes e Validação

- [x] 4.1 Escrever/atualizar testes de unidade e de widget para `PlantEditorModal` e `InspectionViewModel`, verificando inicialização do toggle com base em `plant.nonExistent`, alternância de estado, habilitação de "Atualizar" e geração do payload com `nonExistent`.
- [x] 4.2 Executar `flutter test` e `dart analyze` para confirmar ausência de erros e integridade do projeto.

## 5. Exibição de Plantas Inexistentes no Mapa com Cor Diferenciada

- [x] 5.1 Atualizar `InspectionLocalStore` para não filtrar plantas com `nonExistent == true` em `readSnapshot`, `prepare` e `toggle`, mantendo todas as plantas disponíveis para visualização e interação.
- [x] 5.2 Atualizar `InspectionView` para gerar e aplicar marcador em amarelo/dourado (#F9A825) para plantas onde `nonExistent` é true, e verde (#2E7D32) para plantas existentes.
- [x] 5.3 Atualizar e adicionar testes para cobrir a inclusão de plantas inexistentes no snapshot da inspeção e a renderização com o ícone correspondente.
- [x] 5.4 Executar testes e static analysis para garantir zero regressões.

