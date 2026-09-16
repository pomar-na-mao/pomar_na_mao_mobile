## 1. Fundações e Injeção de Dependências Nativa

- [x] 1.1 Criar `AppDependencies` em `lib/core/di/app_dependencies.dart` gerenciando a criação, disponibilização e descarte centralizado de serviços, repositórios e ViewModels, e verificar através de teste unitário.
- [x] 1.2 Criar o widget `AppScope` (`InheritedWidget`) em `lib/core/di/app_scope.dart` para expor `AppDependencies` na árvore de widgets sem bibliotecas externas, e verificar via teste de widget.
- [x] 1.3 Atualizar `lib/main.dart` e `lib/app/pomar_na_mao_app.dart` para inicializar e prover o `AppScope`, simplificando a composição de raiz e verificando que a inicialização do app ocorra sem erros.

## 2. Camada de Dados e Desacoplamento de DTOs / DataSources

- [x] 2.1 Criar os DataSources remotos `FarmRemoteDataSource` e `InventoryRemoteDataSource` em `lib/features/farm/data/datasources/` e `lib/features/inventory/data/datasources/`, encapsulando as consultas ao cliente Supabase.
- [x] 2.2 Criar DTOs com deserialização JSON na camada de dados e mappers para as entidades puras de domínio (`FarmPoint`, `Plant`, `Zone`, `InventorySummary`), removendo `fromJson` de `domain/`.
- [x] 2.3 Refatorar os repositórios (`SupabaseFarmRepository`, `SupabasePlantsRepository`, `SupabaseZonesRepository`, `SupabaseInventoryRepository`) para consumir os novos DataSources e DTOs, e verificar a execução de `flutter test test/features/inventory/supabase_inventory_repository_test.dart`.

## 3. Modularização da Apresentação do Inventário

- [x] 3.1 Extrair `InventoryMetricCard` e `InventoryMetricsGrid` de `inventory_view.dart` para `lib/features/inventory/presentation/widgets/`, verificando a renderização através dos testes de widget existentes.
- [x] 3.2 Extrair `InventorySummaryHeader` e `InventoryStatusBanner` para `lib/features/inventory/presentation/widgets/`, reduzindo a complexidade do arquivo principal.
- [x] 3.3 Extrair `InventoryMapSection` para `lib/features/inventory/presentation/widgets/`, preservando a injeção opcional de `mapBuilder` e comportamento de fallback.
- [x] 3.4 Refatorar `InventoryView` para montar os sub-widgets e adotar `ListenableBuilder` para reatividade declarativa, removendo chamadas manuais a `widget.viewModel.dispose()`.

## 4. Reatividade e Ciclo de Vida no Mapa da Fazenda

- [x] 4.1 Refatorar `FarmMapView` para utilizar `ListenableBuilder`, eliminando `addListener`/`removeListener` manuais.
- [x] 4.2 Remover a chamada indevida a `widget.viewModel.dispose()` dentro de `FarmMapView.dispose()`, assegurando que o ViewModel não seja destruído ao alternar abas no `MainShell`.
- [x] 4.3 Verificar a navegação entre abas e preservação de estado executando `flutter test test/app/main_shell_test.dart`.

## 5. Validação Geral e Qualidade de Código

- [x] 5.1 Executar a análise estática com `flutter analyze` e verificar ausência de avisos ou erros.
- [x] 5.2 Executar a suíte de testes com `flutter test` e verificar que todos os 38 testes de unidade e widget passam com sucesso.
