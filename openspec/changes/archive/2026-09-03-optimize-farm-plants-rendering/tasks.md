## 1. Otimização do Repositório Supabase e Paginação

- [x] 1.1 Atualizar `Plant.fromJson` para suportar com valores padrão campos opcionais que não sejam retornados na projeção seletiva do mapa e verificar que o modelo instancia corretamente.
- [x] 1.2 Implementar paginação em lotes com `.range()` em `SupabasePlantsRepository`, removendo o limite estático de 500 registros e aplicando projeção seletiva das colunas necessárias para o mapa (`id, latitude, longitude, zone_id, non_existent`), verificando que todos os lotes são consumidos até carregar a totalidade dos registros.
- [x] 1.3 Mover o parsing e mapeamento da lista de registros JSON para um isolate (`compute` / `Isolate.run`), verificando que o processamento assíncrono não bloqueia o loop da interface.

## 2. Implementação de Clusterização Nativa no Google Maps

- [x] 2.1 Configurar o `ClusterManager` no `FarmMapView` associado ao identificador de clusters `plants` e registrá-lo na propriedade `clusterManagers` do `GoogleMap`, verificando a inicialização sem erros na plataforma nativa.
- [x] 2.2 Associar `clusterManagerId` aos marcadores das plantas e configurar a ação `onClusterTap` para animar a câmera aproximando o zoom no ponto central do agrupamento tocado, verificando o desdobramento visual do cluster.

## 3. Otimização de Performance e Memoização na UI

- [x] 3.1 Memoizar o `Set<Marker>` gerado para que ele seja reconstruído apenas quando os dados de plantas ou o filtro de zona forem alterados, eliminando alocações redundantes a cada chamada de `build()`.
- [x] 3.2 Substituir a geração de assinatura de coordenadas por concatenação de strings em `_fitCameraToAvailableCoordinates()` por uma assinatura leve baseada em quantidade e versão dos dados, verificando a redução drástica de alocação de memória e pausas de GC.

## 4. Verificação e Testes de Regressão

- [x] 4.1 Executar `dart analyze` em todo o projeto garantindo zero alertas e conformidade de tipos e regras de lint.
- [x] 4.2 Validar a navegação e o carregamento do mapa garantindo que 100% das plantas cadastradas são plotadas com agrupamento responsivo e sem perda de fluidez.
