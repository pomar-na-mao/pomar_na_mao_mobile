## Why

Atualmente, a tela de Fazenda limita arbitrariamente a consulta de plantas a 500/1000 registros e renderiza cada registro diretamente como um marcador individual do Google Maps no Flutter. Ao tentar plotar a totalidade das plantas cadastradas na tabela `plants` (que pode conter milhares de registros), a interface apresenta severa lentidão, travamento de quadros (jank) e alto consumo de memória devido à sobrecarga de renderização nativa de milhares de marcadores e sobrecarga do platform channel. É necessário remover esse teto artificial e otimizar tanto a camada de dados quanto a renderização no mapa, garantindo alta performance, fluidez na navegação e exibição de 100% das plantas disponíveis.

## What Changes

- **Remoção do limite arbitrário de plantas**: Implementar paginação em lote (batching/range) no repositório Supabase para carregar todas as plantas da tabela `plants` sem truncamento no limite de 1.000 linhas do PostgREST.
- **Otimização do payload de consulta**: Selecionar apenas as colunas necessárias para plotagem e identificação básica no mapa (`id`, `latitude`, `longitude`, `zone_id`, `non_existent`), reduzindo o consumo de banda e memória em mais de 80%.
- **Processamento fora da UI thread**: Decodificação e mapeamento dos registros em isolate (`compute` / `Isolate.run`) para não travar a UI durante o parsing de grandes volumes de dados.
- **Clusterização nativa de marcadores**: Utilizar o `ClusterManager` nativo do `google_maps_flutter` para agrupar marcadores em níveis de zoom distantes e expandir em marcadores individuais conforme o zoom aumenta.
- **Memoização e eliminação de gargalos na UI**: Caching do conjunto de marcadores e substituição do cálculo de assinatura de câmera baseado em concatenação de strings de todas as coordenadas por comparação eficiente de estado.

## Capabilities

### Modified Capabilities
- `farm-map`: Atualizar os requisitos de carregamento para suportar a totalidade das plantas cadastradas na tabela `plants` via paginação transparente, e atualizar o requisito de representação geográfica para suportar agrupamento (clustering) e renderização otimizada com alta taxa de quadros.

## Impact

- **Código afetado**:
  - `lib/features/farm/data/supabase_plants_repository.dart`
  - `lib/features/farm/presentation/farm_map_view.dart`
  - `lib/features/farm/presentation/farm_map_view_model.dart`
- **Dependências**: Usa recursos nativos do plugin `google_maps_flutter` (^2.18.0 já instalado).
- **APIs / Banco de Dados**: Acesso à tabela `plants` no Supabase com paginação em lotes de 1.000 itens até carregar todos os registros.
