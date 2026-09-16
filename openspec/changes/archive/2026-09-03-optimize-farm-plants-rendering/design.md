## Context

A tela Fazenda exibe as plantas da fazenda no mapa Google interativo (`FarmMapView`). Atualmente:
1. `SupabasePlantsRepository` impõe `limit(500)`. Ao remover o limite, o PostgREST do Supabase trunca a resposta em 1.000 registros caso não haja paginação por `.range()`.
2. A consulta busca todas as colunas (`select()`), gerando tráfego de dados desnecessário (21 colunas por planta).
3. A desserialização de milhares de registros é executada na thread principal (UI thread).
4. Em `FarmMapView`, `_markers` reconstrói um `Set<Marker>` com todos os marcadores a cada chamada de `build()`, e cada marcador é repassado individualmente via Platform Channel para o Google Maps nativo sem agrupamento.
5. O método `_fitCameraToAvailableCoordinates()` concatena as strings de latitude e longitude de todas as plantas a cada verificação de câmera, gerando alocações pesadas e pressão no Garbage Collector.

## Goals / Non-Goals

**Goals:**
- Carregar todas as plantas da tabela `plants` sem interrupção no limite de 1.000 registros, utilizando paginação por lotes (`range`).
- Otimizar o tráfego de rede e a memória, requisitando apenas as colunas essenciais para o mapa (`id, latitude, longitude, zone_id, non_existent`).
- Executar o parsing dos dados em isolate em segundo plano (`compute` / `Isolate.run`), impedindo travamentos na UI.
- Implementar agrupamento nativo com `ClusterManager` do `google_maps_flutter`, exibindo clusters com contagem quando distante e marcadores individuais no zoom aproximado.
- Adicionar interação de zoom ao tocar em um cluster (`onClusterTap`), facilitando a exploração rápida de talhões e quadras.
- Otimizar a criação de marcadores e o cálculo de limites de câmera para eliminar gargalos de CPU na interface.

**Non-Goals:**
- Implementar servidor próprio de Vector Tiles (MVT / Mapbox) ou proxy GIS customizado.
- Sincronização offline completa com banco local (Drift/Isar) neste momento (foco na performance de carregamento e renderização do mapa).
- Alterar telas ou repositórios fora do fluxo da Fazenda (`farm`).

## Decisions

### Decisão 1: Paginação por faixa (`.range()`) em lotes de 1.000 registros
- **Escolha**: O repositório realiza requisições iterativas em lotes (`.range(start, end)` com tamanho 1.000) até que um lote retorne menos que o tamanho da página, consolidando a lista completa.
- **Alternativas consideradas**:
  - *Consulta única sem limite*: PostgREST trunca silenciosamente em 1.000 registros devido à configuração `max-rows` do servidor.
  - *Bounding-box querying (RPC PostGIS no backend)*: Exigiria criar funções SQL específicas no Supabase e disparar requisições de rede a cada movimento de câmera do mapa, aumentando a latência e o consumo de dados móveis.

### Decisão 2: Projeção seletiva de colunas para o mapa
- **Escolha**: Consultar apenas as colunas necessárias para visualização e filtragem: `'id, latitude, longitude, zone_id, non_existent'`.
- **Alternativas consideradas**:
  - *Manter `select('*')`*: Trafega 21 campos (descrições, datas, identificadores de sincronização, timestamps) consumindo megabytes adicionais de payload e memória desnecessariamente. Detalhes completos de uma planta podem ser consultados pontualmente caso o usuário abra uma ficha de detalhes.

### Decisão 3: Desserialização em Isolate (`compute`)
- **Escolha**: O mapeamento de `List<Map<String, dynamic>>` para `List<Plant>` é delegado a `compute` / `Isolate.run`.
- **Alternativas consideradas**:
  - *Parsing na UI thread*: O parsing de 10.000+ mapas JSON bloqueia o loop de eventos da UI por 50 a 150ms, causando travamento perceptível durante o carregamento.

### Decisão 4: Agrupamento Nativo com `ClusterManager` do `google_maps_flutter`
- **Escolha**: Utilizar o `ClusterManager` oficial integrado ao `google_maps_flutter` (^2.18.0), atribuindo `clusterManagerId` aos marcadores e configurando o callback `onClusterTap` para dar zoom e focar no cluster tocado.
- **Alternativas consideradas**:
  - *QuadTree / Supercluster customizado em Dart*: Requereria cálculo manual de projeções de tela e reconstrução contínua de marcadores a cada frame de movimento da câmera, gerando sobrecarga adicional no Flutter. O `ClusterManager` executa a agregação e desenho diretamente no motor nativo da Google Maps SDK (C++/Java/Obj-C).

### Decisão 5: Memoização de Marcadores e Assinatura Leve de Câmera
- **Escolha**:
  1. Manter os `Marker`s em cache no estado do widget ou no ViewModel, recalculando-os apenas quando a lista de plantas filtradas mudar (ex: mudança de zona ou novo carregamento).
  2. Substituir o `plants.map((p) => ...).join('|')` por uma assinatura baseada em contagem, zona selecionada e IDs limites, ou verificação de versão de dados.
- **Alternativas consideradas**:
  - *Recomputar markers em todo `build()`*: Causa pressão severa no garbage collector a cada atualização de GPS ou evento de animação.

## Risks / Trade-offs

- **[Risco] Volume extremo de plantas (ex: > 50.000 plantas) aumentando o tempo de download inicial** → *Mitigação*: A projeção de 5 colunas mantém o tamanho total em menos de ~2 MB para 20.000 plantas. O repositório pode emitir progresso caso desejado e a paginação em lotes de 1.000 é rápida e estável.
- **[Risco] Marcadores individuais muito densos em zoom máximo** → *Mitigação*: O `ClusterManager` só desmembra marcadores individuais no nível de zoom onde eles são espacialmente distinguíveis, preservando a taxa de 60 FPS.
- **[Risco] Customização de ícones dos clusters** → *Mitigação*: O `ClusterManager` utiliza a apresentação padrão de clusters da SDK do Google Maps, que é visualmente limpa e altamente performática.
