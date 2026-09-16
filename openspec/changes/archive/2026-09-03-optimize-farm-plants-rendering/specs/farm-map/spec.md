## MODIFIED Requirements

### Requirement: Carregar plantas cadastradas
O aplicativo SHALL consultar a totalidade dos registros disponíveis na tabela `public.plants` do projeto Supabase configurado utilizando paginação em lotes (sem truncamento por limites artificiais ou tetos de página da API), processando a carga e decodificação dos registros de forma assíncrona fora da thread principal de interface para disponibilização no mapa.

#### Scenario: Consulta concluída com plantas
- **WHEN** a consulta ao Supabase retorna registros da tabela `plants`
- **THEN** o sistema conclui o carregamento de todos os registros disponíveis paginados até a exaustão da tabela e disponibiliza o conjunto completo para o mapa sem travar a interface do usuário

#### Scenario: Consulta concluída sem plantas
- **WHEN** a consulta ao Supabase não retorna registros
- **THEN** o sistema mantém o mapa utilizável e informa que nenhuma planta foi encontrada

#### Scenario: Falha ao carregar plantas
- **WHEN** a consulta ao Supabase falha
- **THEN** o sistema mantém a tela Fazenda estável e apresenta uma mensagem de erro com uma ação para tentar novamente

### Requirement: Representar todas as plantas no mapa
O aplicativo SHALL representar geograficamente a totalidade das plantas carregadas através de agrupamento inteligente (clustering) em níveis de zoom distantes e marcadores individuais em níveis de zoom aproximados, mantendo interações de câmera e navegação fluidas sem travamento.

#### Scenario: Plotar múltiplas plantas
- **WHEN** duas ou mais plantas são carregadas com sucesso
- **THEN** o mapa exibe as plantas sem omitir registros, agrupando-as visualmente com contagem em zoom panorâmico e desdobrando-as em marcadores individuais nas respectivas coordenadas quando aproximado o zoom

#### Scenario: Identificar uma planta
- **WHEN** o usuário toca no marcador de uma planta
- **THEN** o sistema identifica a planta utilizando ao menos seu `id`
