## Why

A tela Inventário hoje está vazia e não oferece uma visão rápida da capacidade produtiva nem da configuração da propriedade. Transformá-la em um painel resumido permite que o usuário compreenda o estado do pomar e sua área de cultivo assim que abre o aplicativo.

## What Changes

- Substituir a tela vazia de Inventário por um painel responsivo, organizado em blocos visuais, com hierarquia clara, cores de alto contraste e sombras discretas.
- Exibir dois indicadores calculados a partir da totalidade de `public.plants`: plantas existentes (`non_existent = false`) e posições disponíveis para plantio (`non_existent = true`).
- Apresentar os dados da propriedade: “Sítio São Francisco”, área total de 54 ha, cultivo avocado, espaçamento de 7 × 7 m a 8 × 8 m, classificação semi-adensado, adensamento de 70 a 100 plantas/ha e variedade Hass.
- Incorporar `assets/images/avocado.png` como elemento ilustrativo do resumo do cultivo, com tratamento responsivo e descrição semântica.
- Exibir um mapa compacto e interativo enquadrado na propriedade, contendo apenas os polígonos da fazenda e da Zona A, sem marcadores ou agrupamentos de plantas.
- Oferecer estados explícitos de carregamento, erro com nova tentativa e indisponibilidade parcial dos dados ou polígonos.

## Capabilities

### New Capabilities

- `inventory-dashboard`: Painel de inventário com indicadores de plantas, informações agronômicas da propriedade, ilustração do cultivo e mapa dos polígonos da fazenda e da Zona A.

### Modified Capabilities

- Nenhuma.

## Impact

- Afeta a feature Flutter `lib/features/inventory`, que passará a possuir camadas de domínio, dados e apresentação para o painel.
- Reutiliza os contratos e as fontes Supabase de plantas, zonas, regiões e limite da fazenda já empregados pela feature Fazenda, evitando duplicação de regras de mapeamento.
- Altera a composição de dependências em `lib/main.dart` e/ou no shell principal para fornecer um ViewModel próprio ao destino Inventário.
- Usa o Google Maps já configurado e o asset existente `assets/images/avocado.png`; não requer nova dependência nem alteração de schema do banco.
- Mantém os demais destinos e o comportamento do mapa Fazenda inalterados.
