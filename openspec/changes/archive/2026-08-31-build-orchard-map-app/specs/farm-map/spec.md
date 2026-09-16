## Purpose

Permitir que o usuário visualize no mapa a distribuição geográfica das plantas cadastradas na fazenda e sua própria posição quando disponível.

## ADDED Requirements

### Requirement: Exibir o mapa da fazenda
O aplicativo SHALL apresentar um mapa Google interativo como conteúdo principal do destino Fazenda.

#### Scenario: Abrir a Fazenda
- **WHEN** o usuário seleciona o destino Fazenda
- **THEN** o sistema exibe o mapa e informa visualmente enquanto os dados das plantas estão sendo carregados

### Requirement: Carregar plantas cadastradas
O aplicativo SHALL consultar a tabela `public.plants` do projeto Supabase configurado e considerar cada registro retornado para apresentação no mapa.

#### Scenario: Consulta concluída com plantas
- **WHEN** a consulta ao Supabase retorna registros da tabela `plants`
- **THEN** o sistema conclui o carregamento e disponibiliza os registros para representação geográfica

#### Scenario: Consulta concluída sem plantas
- **WHEN** a consulta ao Supabase não retorna registros
- **THEN** o sistema mantém o mapa utilizável e informa que nenhuma planta foi encontrada

#### Scenario: Falha ao carregar plantas
- **WHEN** a consulta ao Supabase falha
- **THEN** o sistema mantém a tela Fazenda estável e apresenta uma mensagem de erro com uma ação para tentar novamente

### Requirement: Representar todas as plantas no mapa
O aplicativo SHALL criar um marcador distinto na latitude e longitude de cada planta retornada pela consulta.

#### Scenario: Plotar múltiplas plantas
- **WHEN** duas ou mais plantas são carregadas com sucesso
- **THEN** o mapa exibe um marcador nas coordenadas de cada planta sem omitir registros

#### Scenario: Identificar uma planta
- **WHEN** o usuário toca no marcador de uma planta
- **THEN** o sistema identifica a planta utilizando ao menos seu `id`

### Requirement: Solicitar e exibir a posição do usuário
O aplicativo SHALL solicitar a permissão de localização em tempo de execução e SHALL exibir a posição atual do usuário no mapa quando o serviço, a permissão e uma posição válida estiverem disponíveis.

#### Scenario: Localização autorizada
- **WHEN** o serviço de localização está ativo, o usuário concede a permissão e uma posição é obtida
- **THEN** o mapa indica a posição atual do usuário

#### Scenario: Permissão negada
- **WHEN** o usuário nega a permissão de localização
- **THEN** o sistema mantém as plantas visíveis e informa que a posição do usuário não pode ser exibida

#### Scenario: Serviço de localização indisponível
- **WHEN** o serviço de localização está desativado ou uma posição não pode ser obtida
- **THEN** o sistema mantém as plantas visíveis e informa a indisponibilidade da posição do usuário

### Requirement: Ajustar a visualização a dados disponíveis
O aplicativo SHALL escolher uma região inicial útil usando as coordenadas disponíveis das plantas ou do usuário e SHALL utilizar uma região padrão configurada quando nenhuma coordenada estiver disponível.

#### Scenario: Existem plantas carregadas
- **WHEN** o mapa recebe uma ou mais plantas
- **THEN** a câmera apresenta uma região que permite localizar as plantas carregadas

#### Scenario: Não existem coordenadas disponíveis
- **WHEN** não há plantas e a posição do usuário não está disponível
- **THEN** o mapa abre em uma região padrão sem falhar
