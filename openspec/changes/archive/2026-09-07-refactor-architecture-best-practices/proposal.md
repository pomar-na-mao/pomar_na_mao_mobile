## Why

O aplicativo Pomar na Mão possui uma base de código funcional, porém apresenta acoplamentos e divergências em relação às recomendações oficiais da documentação do Flutter e Dart:
1. **Acoplamento na camada de dados**: os repositórios chamam diretamente o cliente Supabase e os modelos de domínio contêm lógica de deserialização JSON (`fromJson`) acoplada ao esquema de banco de dados.
2. **Gerenciamento de ciclo de vida frágil de ViewModels**: `ChangeNotifier`s criados no `main.dart` são descartados (`dispose()`) dentro dos métodos `dispose()` de widgets filhos (`FarmMapView` e `InventoryView`), causando falhas em desmontagens e remontagens de tela.
3. **Acúmulo de responsabilidades na camada de apresentação**: a tela `InventoryView` possui mais de 800 linhas em um único arquivo, misturando lógica de formatação, layout, estilos locais e montagem de componentes.
4. **Reatividade manual**: widgets utilizam `addListener` com chamadas manuais a `setState`, em vez do widget oficial e idiomático `ListenableBuilder`.

Refatorar a arquitetura neste momento garante manutenibilidade, testabilidade e escalabilidade do projeto, respeitando estritamente a restrição de **não adicionar nenhuma dependência externa**.

## What Changes

- **Injeção de Dependências Nativa (`AppScope` / `InheritedWidget`)**:
  - Implementar um mecanismo nativo de composição e provisão de dependências baseado em `InheritedWidget` (ou Composição na Raiz do App), eliminando a passagem manual excessiva de ViewModels via construtores e corrigindo a propriedade do ciclo de vida (`dispose`) das instâncias.
- **Camada de Apresentação (MVVM Moderno e Reatividade Declarativa)**:
  - Migrar o consumo dos ViewModels para `ListenableBuilder`, reduzindo a necessidade de gerenciar inscrições manuais via `addListener` e `setState`.
  - Modularizar telas volumosas: decompor `InventoryView` em widgets especialistas reutilizáveis em `presentation/widgets/` (ex: `InventoryHeader`, `InventoryMetricsGrid`, `InventoryMapSection`, `InventoryStatusCard`).
  - Corrigir a posse dos ViewModels para que views apenas consumam os dados sem chamar indevidamente `viewModel.dispose()`.
- **Camada de Dados (DataSources e DTOs)**:
  - Criar DataSources/Services dedicados para isolar as chamadas diretas ao cliente Supabase (`FarmRemoteDataSource`, `InventoryRemoteDataSource`).
  - Isolar a serialização (`fromJson` / `toJson`) em DTOs (Data Transfer Objects) ou mappers na camada de dados, livrando os modelos de domínio de dependências do formato de persistência.
- **Camada de Domínio (Pureza de Domínio)**:
  - Manter entidades de domínio como classes puras e imutáveis, sem dependência de bibliotecas externas de transporte ou formatos de API.
  - Padronizar o tratamento de erros e resultados sem bibliotecas extras (utilizando tipos de resultado nativos com Dart Records ou classes leves de `Result`/`AppException`).
- **Organização de Pastas e Padrão de Código**:
  - Alinhar a estrutura das pastas por feature (`presentation`, `domain`, `data`) e `core` (utilitários, tema e scoped dependencies).
  - Aplicar recursos modernos do Dart 3 (pattern matching, switch expressions, records).

## Capabilities

### New Capabilities
<!-- Nenhuma nova funcionalidade externa; refatoração arquitetural pura. -->

### Modified Capabilities
<!-- Nenhuma alteração de requisitos de comportamento externo; o comportamento funcional do usuário permanece idêntico. -->

## Impact

- **Código afetado**:
  - `lib/main.dart` e `lib/app/`: inicialização e escopo de dependências.
  - `lib/features/farm/`: separação de DataSources, repositórios, modelos e ViewModels.
  - `lib/features/inventory/`: quebra da `InventoryView` monolítica em widgets componentes e desacoplamento de dados.
  - `lib/core/`: adição de helpers estruturais (injeção nativa e tratamento de erros).
  - `test/`: atualização de testes para acompanhar a modularização e injeção sem alterar os comportamentos cobertos.
- **Dependências**:
  - Nenhuma biblioteca ou pacote externo será adicionado ao `pubspec.yaml`.
- **Quebras de API / Comportamento**:
  - Nenhuma quebra externa de comportamento para o usuário final.
