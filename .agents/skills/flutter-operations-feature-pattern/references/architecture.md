# Arquitetura para funcionalidades de Operações

Use a separação já praticada por Pulverização. O fluxo de dependências é:

`View/widgets -> ViewModel -> Repository -> LocalStore/Database + RemoteDataSource`

Modelos, filtros de posição, geometria e políticas de domínio apoiam o ViewModel e o Repository sem depender da View.

## Estrutura recomendada

Dentro de `lib/features/operations/`:

```text
domain/
  <feature>_models.dart
  <feature>_geometry_service.dart       # quando houver cálculo espacial
  <feature>_location_filter.dart        # quando houver política de GPS
data/
  <feature>_repository.dart             # contrato + implementação padrão
  <feature>_local_store.dart
  <feature>_database.dart
  <feature>_remote_data_source.dart
presentation/
  <feature>_view.dart
  <feature>_view_model.dart
  widgets/
    <feature>_*.dart
```

Nem toda funcionalidade precisa de todos os arquivos. Crie uma camada apenas quando houver responsabilidade real; não concentre responsabilidades na View para evitar um arquivo.

## Responsabilidades

### Domain

- Modelos, enums de estado, regras puras, validações e cálculo espacial.
- Prefira objetos imutáveis e métodos `copyWith` quando houver transições persistidas.
- Mantenha regras testáveis sem `BuildContext` e, sempre que possível, sem Flutter.
- A política de GPS valida idade, precisão, coordenadas, velocidade/outliers, suavização e deadband. A View não filtra amostras.

### Data

- O `abstract interface class <Feature>Repository` é o contrato consumido pelo ViewModel.
- A implementação padrão coordena persistência local, sincronização remota, conversão de payload e fallback offline.
- `LocalStore` traduz modelos para operações do banco local; `Database` possui schema, migrations e ciclo de conexão.
- `RemoteDataSource` encapsula Supabase/RPC e não expõe detalhes do cliente à apresentação.
- Operações de campo devem favorecer offline-first: salvar localmente, mostrar o registro local, revisar e sincronizar explicitamente.
- Atualize status de sincronização de forma transacional/coerente: rascunho, revisado, sincronizando, sincronizado ou erro. Em falha remota, preserve dados recuperáveis e um estado que permita nova tentativa.

Fonte canônica: `lib/features/operations/data/spraying_repository.dart`, `spraying_local_store.dart`, `spraying_database.dart` e `spraying_remote_data_source.dart`.

### ViewModel

- Estende `ChangeNotifier` conforme o padrão atual e recebe dependências pelo construtor.
- Mantém o estado da tela, coordena casos de uso, inicia/cancela streams, converte resultados em feedback/erro e chama `notifyListeners()` em transições observáveis.
- Não recebe `BuildContext`, não abre modal e não navega.
- Exponha coleções não modificáveis ou getters derivados; não permita que widgets mutem estado interno.
- Separe flags por operação (`loading`, `saving`, `syncing`) e evite um loading global que bloqueie localização.
- No GPS, assine `watchLocation()`, passe cada amostra pelo filtro de domínio e publique somente amostras aceitas. Cancele a assinatura em `stopLocationTracking()` e `dispose()`.
- Persistência e rede passam pelo Repository; acesso a catálogos compartilhados passa pelo repositório compartilhado existente.

Fonte canônica: `lib/features/operations/presentation/spraying_view_model.dart`.

### View e widgets

- A View compõe layout, mapa, controllers, lifecycle, navegação e abertura de modais.
- Widgets recebem dados e callbacks ou o ViewModel quando precisam observar vários estados relacionados; não acessam banco ou Supabase.
- Extraia bottom sheets, cards e barras de ação para `presentation/widgets/`.
- Controllers de texto, mapa e animação pertencem ao widget que controla seu ciclo e devem ser descartados.
- Operações iniciadas após frame devem testar `mounted`; callbacks assíncronos devem testar `context.mounted` antes de navegar ou mostrar feedback.
- Use `ListenableBuilder` nos limites adequados para não reconstruir uma árvore maior que o necessário.

Fonte canônica: `lib/features/operations/presentation/spraying_view.dart` e `presentation/widgets/spraying_*.dart`.

## Injeção e registro

- Registre Database, LocalStore, RemoteDataSource, Repository e ViewModel em `lib/core/di/app_dependencies.dart`.
- Exponha a dependência pelo `AppScope` existente e consuma-a pela árvore; permita injeção explícita no construtor da View para testes.
- Não replique os fallbacks privados de Pulverização em novas Views como solução de produção. Eles existem para isolamento/testabilidade do componente atual; a composição real pertence ao container.
- Registre a entrada da funcionalidade pelos mecanismos existentes de Operações, como `operation_definition.dart` e `operations_view.dart`, sem navegação hardcoded espalhada.
- O `dispose()` central deve encerrar ViewModels criados, repositórios observáveis e bancos pertencentes ao container.

## Offline e sincronização

Para coletas de campo:

1. Crie um ID local estável.
2. Persista o rascunho e dados incrementais localmente.
3. Finalize a coleta sem exigir rede.
4. Permita revisão e enriquecimento antes do envio.
5. Monte o payload no limite Repository/RemoteDataSource.
6. Marque `syncing` antes do envio, `synced` após confirmação integral e `error` se falhar.
7. Preserve o registro após sincronizar até exclusão explícita, conforme o padrão da lista local.

Se houver cálculo remoto com equivalente local, mantenha fallback determinístico e testado, como o cálculo de plantas afetadas em Pulverização.

## Documentação e migration obrigatórias

Toda funcionalidade implementada ou modificada sob esta skill deve entregar, no mesmo conjunto de mudanças, os três artefatos abaixo. Não considere o trabalho concluído se algum deles estiver ausente.

### 1. Seção 20 do `database.md`

A seção 20 documenta processos funcionais mobile e desktop.

- Ao criar uma funcionalidade nova, crie o próximo item `20.n` disponível, preservando a numeração e a organização do documento.
- Ao modificar uma funcionalidade existente, edite o item `20.n` que já a descreve; não crie uma seção duplicada.
- Registre objetivo, acesso/navegação, comportamento da interface, fluxo passo a passo, estados relevantes, persistência offline/local e sincronização com o backend.
- Descreva o comportamento efetivamente implementado. Não deixe o documento expressar um fluxo antigo ou planejado.

Use como referências de formato os itens `20.1` Inspeção, `20.2` Pulverização, `20.3` MIPD e `20.12` Atividade.

### 2. Seção 25 do `database.md`

A seção 25 mantém as extensões executáveis e o contrato de banco das funcionalidades.

- Ao criar uma funcionalidade nova, crie o próximo item `25.n` disponível.
- Ao modificar uma funcionalidade existente, atualize a subseção correspondente em 25 e preserve seu histórico/coerência; não publique uma segunda definição conflitante sem explicar a substituição incremental.
- Documente tabelas, colunas, constraints, índices, triggers, funções/RPCs, RLS, grants, Storage e integrações afetadas, conforme aplicável.
- Indique o nome exato da migration em `supabase/migrations` e mantenha o SQL/documentação semanticamente alinhados com ela.
- Inclua ordem de implantação, compatibilidade e estratégia de rollback sem sugerir perda destrutiva de dados.

Use como referências de formato os itens `25.1` MIPD, `25.5` Atividade e as extensões posteriores.

### 3. Migration em `supabase/migrations`

Crie sempre um novo arquivo `.sql`; nunca edite uma migration já aplicada para representar uma mudança posterior.

- Use o padrão `<YYYYMMDDHHMMSS>_<descricao_em_snake_case>.sql`, com timestamp único e ordem posterior às migrations existentes.
- Antes de escrever, inspecione as migrations recentes e a migration anterior da mesma funcionalidade.
- Use schema explícito (`public`, `extensions`), transação `begin`/`commit` quando compatível e os timeouts adotados pelo projeto em mudanças potencialmente bloqueantes.
- Torne DDL e seeds idempotentes quando possível (`if exists`, `if not exists`, `on conflict`). Ao substituir funções, trate assinaturas antigas explicitamente.
- Preserve dados existentes e compatibilidade com versões anteriores do aplicativo. Mudança destrutiva exige migração de dados e autorização específica.
- Para funções `security definer`, fixe `search_path`, valide completamente o payload e aplique apenas os grants mínimos necessários.
- Para tabelas expostas, habilite RLS e defina políticas deliberadas; não confie somente na UI mobile.
- Inclua comentários que identifiquem objetivo e decisões não óbvias, sem copiar documentação extensa para o SQL.
- Valide a migration com as ferramentas Supabase disponíveis e revise advisors quando o ambiente permitir. Não aplique em ambiente remoto sem autorização explícita.

O código Flutter, a seção 20, a seção 25 e a migration devem usar os mesmos nomes de funcionalidade, códigos de operação, campos, estados e contratos de payload.

## Testes obrigatórios por tipo de mudança

- Domain: filtros, geometria, transições e casos-limite com testes unitários.
- ViewModel: início/pausa/finalização, persistência, erros, localização, cancelamento de stream e sincronização com fakes.
- Repository: payload, estados de sync, fallback offline e falhas parciais.
- Widgets: header de modal, foco inicial, teclado, quebra das ações, status/ações dos cards e ausência de overflow.
- Mapa: helpers de câmera e heading como funções puras; não dependa de teste end-to-end para toda a matemática.

Referências existentes:

- `test/features/operations/spraying_location_filter_test.dart`
- `test/features/operations/spraying_map_camera_test.dart`
- `test/features/operations/spraying_heading_test.dart`
- `test/features/operations/spraying_geometry_service_test.dart`
- `test/features/operations/spraying_sync_counts_test.dart`
- `test/features/operations/spraying_view_model_test.dart`

Ao corrigir um bug, acrescente um teste que falhe antes da correção. Ao extrair componente compartilhado, mantenha testes que garantam que Pulverização não mudou visual ou funcionalmente.

## Checklist de revisão arquitetural

- A View apenas apresenta e coordena UI?
- O ViewModel é independente de `BuildContext`?
- Regras puras estão no domínio?
- Persistência e chamadas remotas passam pelo Repository?
- O fluxo funciona offline e permite retentativa?
- Dependências vêm do container e podem ser substituídas em teste?
- Streams/controllers são cancelados?
- Estados assíncronos não bloqueiam o GPS nem criam loading de “estabilização”?
- Componentes idênticos foram reutilizados ou extraídos?
- Existem testes proporcionais ao risco?
