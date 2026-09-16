## Context

O aplicativo Pomar na Mão foi construído utilizando Flutter e Dart com comunicação direta ao Supabase via `supabase_flutter`, renderização de mapas com `google_maps_flutter` e geolocalização com `geolocator`.

Atualmente, o projeto possui as seguintes características e limitações:
- Os repositórios executam queries diretamente contra o `SupabaseClient` e mapeiam os resultados chamando métodos `.fromJson` definidos diretamente nas entidades do pacote `domain/`.
- Os ViewModels (`FarmMapViewModel` e `InventoryViewModel`) são instanciados no `main.dart` e passados por meio de múltiplos construtores encadeados (`PomarNaMaoApp` -> `MainShell` -> `FarmMapView` / `InventoryView`).
- O ciclo de vida dos ViewModels está incorreto: `FarmMapView.dispose()` e `InventoryView.dispose()` executam `widget.viewModel.dispose()`, descartando instâncias que foram criadas no topo da aplicação.
- A tela `InventoryView` possui mais de 800 linhas em um único arquivo, combinando layout, formatação de métricas, lógica condicional e tratamento de erros.
- A reatividade é implementada manualmente com `addListener` e `setState` em `StatefulWidget`s, em vez do widget padrão moderno `ListenableBuilder`.

**Restrição mandatória**: Nenhuma biblioteca externa (`provider`, `riverpod`, `bloc`, `get_it`, etc.) pode ser adicionada. Toda a arquitetura deve utilizar apenas recursos nativos do Flutter SDK e da linguagem Dart.

## Goals / Non-Goals

**Goals:**
- Implementar uma arquitetura em 3 camadas estritas (Apresentação, Domínio e Dados) alinhada à documentação oficial do Flutter.
- Introduzir injeção de dependências e gerenciamento de ciclo de vida nativo via `InheritedWidget` (`AppScope`) e `AppDependencies`.
- Corrigir a posse e ciclo de vida dos ViewModels, garantindo que as Views apenas escutem os estados e nunca executem `dispose()` em instâncias compartilhadas.
- Adotar `ListenableBuilder` para uma reatividade limpa, declarativa e granular, eliminando o boilerplate de `addListener`/`removeListener`.
- Decompor `InventoryView` em widgets especialistas desacoplados sob `presentation/widgets/`.
- Desacoplar a camada de dados criando DataSources dedicados para o Supabase e isolando a deserialização JSON em DTOs/mappers, preservando as entidades de domínio puras.
- Manter 100% dos testes existentes passando sem regressão.

**Non-Goals:**
- Não adicionar dependências ou alterar o arquivo `pubspec.yaml`.
- Não alterar regras de negócio, tabelas do Supabase, queries de dados ou contratos de dados externos.
- Não alterar a identidade visual, temas de cores ou fluxos de navegação percebidos pelo usuário final.

## Decisions

### 1. Injeção de Dependências e Composição Nativa (`AppScope` via `InheritedWidget`)
- **Decisão**: Criar uma classe `AppDependencies` responsável por instanciar DataSources, Repositories e ViewModels, disponibilizada para a árvore de widgets através de um `InheritedWidget` chamado `AppScope`.
- **Alternativas consideradas**:
  - *Passagem manual por construtores*: Mantém acoplamento excessivo e propagação de parâmetros por toda a árvore (prop drilling).
  - *Singletons estáticos globais*: Prejudicam a testabilidade e o isolamento de estados entre testes.
- **Vantagens**: Solução idiomática do Flutter (sem libs extras), simplifica o `main.dart` e gerencia o `dispose()` de forma centralizada e segura no fechamento do app ou troca de escopo.

### 2. Reatividade Granular com `ListenableBuilder`
- **Decisão**: Migrar as views de `addListener`/`setState` para `ListenableBuilder`.
- **Alternativas consideradas**:
  - *Manter `StatefulWidget` com `setState`*: Código mais verboso, propenso a esquecimento de `removeListener` e reconstrução desnecessária da tela inteira.
  - *Streams / StreamBuilder*: Complexidade desnecessária para estados síncronos já baseados em `ChangeNotifier`.
- **Vantagens**: Padrão recomendado pela documentação oficial do Flutter desde o Flutter 3.10, reconstrói apenas os ramos necessários da árvore e gerencia a subscrição automaticamente.

### 3. Decomposição Modular da `InventoryView`
- **Decisão**: Dividir `lib/features/inventory/presentation/inventory_view.dart` (828 linhas) em múltiplos arquivos modulares em `lib/features/inventory/presentation/widgets/`:
  - `inventory_summary_header.dart`: cabeçalho com identificação do sítio, área e status.
  - `inventory_metrics_grid.dart`: grid de cartões de métricas (plantas totais, espécies, taxa de ocupação, etc.).
  - `inventory_metric_card.dart`: cartão base reutilizável para exibição de métricas numéricas e percentuais.
  - `inventory_map_section.dart`: encapsulamento do mapa de limites e polígonos da propriedade.
  - `inventory_status_banner.dart`: banners de alerta, erro e carregamento com botão de repetição.
- **Alternativas consideradas**:
  - *Manter métodos privados `_buildX()` no mesmo arquivo*: Não resolve o tamanho excessivo do arquivo nem permite testes unitários de componentes isolados.

### 4. Camada de Dados: DataSources e DTOs
- **Decisão**:
  - Introduzir DataSources dedicados (`FarmRemoteDataSource`, `InventoryRemoteDataSource`) para encapsular o cliente Supabase.
  - Transferir a deserialização JSON (`fromJson`) para DTOs ou funções mapper em `data/`, tornando as entidades de `domain/` classes Dart puras e imutáveis sem acoplamento a chaves de banco de dados.
- **Alternativas consideradas**:
  - *Manter `fromJson` nas entidades de domínio*: Viola o princípio de separação de responsabilidades e acopla regras de domínio a contratos da API/DB.

### 5. Ciclo de Vida dos ViewModels
- **Decisão**: A propriedade do ciclo de vida dos ViewModels fica estritamente com quem os cria (`AppDependencies` / `AppScope`). `FarmMapView` e `InventoryView` recebem ou acessam o ViewModel apenas para leitura/interação, sem invocar `dispose()` em seus próprios métodos `dispose()`.
- **Alternativas consideradas**:
  - *Fazer a View instanciar seu próprio ViewModel*: Dificulta o compartilhamento de dados e o cache entre abas no `MainShell`.

## Risks / Trade-offs

- **[Risco] Quebra em testes de widgets existentes devido a mudanças nos construtores das telas.**
  - *Mitigação*: Manter suporte a injeção via construtor opcional nas Views (`InventoryView(viewModel: ...)`), permitindo que os testes existentes continuem passando mocks diretamente sem necessidade de refatorar todos os testes de uma só vez.
- **[Risco] Reconstruções excessivas com `ListenableBuilder` se mal posicionado.**
  - *Mitigação*: Isolar o `ListenableBuilder` em sub-árvores específicas (por exemplo, na grade de métricas e no container do mapa) em vez de envolver o `Scaffold` inteiro.
- **[Risco] Complexidade adicional de arquivos pequenos.**
  - *Mitigação*: A estrutura de diretórios seguirá o padrão do skill `flutter-apply-architecture-best-practices` (`ui/features/...`, `data/...`, `domain/...`), facilitando a navegação.
