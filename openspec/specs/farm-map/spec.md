# farm-map Specification

## Purpose

Permitir que o usuário visualize no mapa a distribuição geográfica das plantas cadastradas na fazenda e sua própria posição quando disponível.

## Requirements

### Requirement: Exibir o mapa da fazenda
O aplicativo SHALL apresentar um mapa Google interativo como conteúdo principal do destino Fazenda.

#### Scenario: Abrir a Fazenda
- **WHEN** o usuário seleciona o destino Fazenda
- **THEN** o sistema exibe o mapa e informa visualmente enquanto os dados das plantas estão sendo carregados

### Requirement: Carregar plantas cadastradas

O aplicativo SHALL disponibilizar no mapa a totalidade dos registros de `public.plants` do projeto configurado a partir do cache local compartilhado, processando carga e decodificação fora da thread principal de interface. Quando ainda não existir uma versão local, SHALL realizar uma única inicialização remota paginada até a exaustão da tabela; quando existir cache, abrir ou tentar novamente na Fazenda SHALL NOT consultar `plants` remotamente. Atualizações posteriores SHALL ser recebidas do carregamento explícito realizado na Inspeção.

#### Scenario: Primeira carga sem cache
- **WHEN** a Fazenda precisa das plantas e nenhuma versão local foi inicializada
- **THEN** o sistema obtém todos os registros disponíveis em páginas, persiste o conjunto completo e o disponibiliza para o mapa sem travar a interface

#### Scenario: Consulta concluída com plantas
- **WHEN** existe um conjunto local de plantas com registros
- **THEN** o sistema disponibiliza a totalidade desse conjunto para o mapa sem enviar nova consulta HTTP a `plants`

#### Scenario: Consulta concluída sem plantas
- **WHEN** o cache contém uma versão completa e confirmada sem registros
- **THEN** o sistema mantém o mapa utilizável, informa que nenhuma planta foi encontrada e não repete automaticamente a consulta remota

#### Scenario: Falha ao carregar plantas
- **WHEN** a inicialização remota falha sem existir cache de plantas utilizável
- **THEN** o sistema mantém a tela Fazenda estável e apresenta uma mensagem de erro com uma ação para tentar novamente

#### Scenario: Inspeção atualiza as plantas
- **WHEN** o carregamento explícito da Inspeção publica uma nova versão do conjunto de plantas
- **THEN** a Fazenda passa a representar essa versão sem iniciar uma atualização remota própria

### Requirement: Representar todas as plantas no mapa
O aplicativo SHALL representar geograficamente a totalidade das plantas carregadas através de agrupamento inteligente (clustering) em níveis de zoom distantes e marcadores individuais em níveis de zoom aproximados, mantendo interações de câmera e navegação fluidas sem travamento.

#### Scenario: Plotar múltiplas plantas
- **WHEN** duas ou mais plantas são carregadas com sucesso
- **THEN** o mapa exibe as plantas sem omitir registros, agrupando-as visualmente com contagem em zoom panorâmico e desdobrando-as em marcadores individuais nas respectivas coordenadas quando aproximado o zoom

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
