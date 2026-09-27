## Purpose

Oferecer uma visão consolidada, legível e responsiva do inventário do pomar, dos parâmetros de cultivo e da área geográfica da propriedade.

## ADDED Requirements

### Requirement: Apresentar o resumo da propriedade
O aplicativo SHALL apresentar no destino Inventário o nome “Sítio São Francisco”, a área total “54 ha” e o cultivo “Avocado” como informações de destaque da propriedade.

#### Scenario: Abrir o Inventário
- **WHEN** o usuário acessa o destino Inventário
- **THEN** o sistema identifica a propriedade como “Sítio São Francisco” e exibe sua área total e seu cultivo sem exigir interação adicional

### Requirement: Contabilizar as plantas por disponibilidade
O aplicativo SHALL consultar a totalidade dos registros acessíveis em `public.plants` e SHALL exibir separadamente a contagem de registros com `non_existent = false` como “Plantas existentes” e a contagem de registros com `non_existent = true` como “Disponíveis para plantio”.

#### Scenario: Existem plantas nas duas categorias
- **WHEN** a fonte de dados contém registros com `non_existent = false` e com `non_existent = true`
- **THEN** o sistema apresenta em indicadores distintos o total exato de cada categoria

#### Scenario: Uma categoria não possui registros
- **WHEN** a consulta de uma das categorias não encontra registros
- **THEN** o indicador correspondente apresenta o valor zero sem tratar o resultado como erro

#### Scenario: Os dados mudam antes de uma nova carga
- **WHEN** o usuário solicita uma nova tentativa ou reabre uma instância ainda não carregada da tela após a fonte de dados ter sido alterada
- **THEN** o sistema consulta novamente os totais e apresenta os valores atuais disponíveis

### Requirement: Exibir os parâmetros de cultivo
O aplicativo SHALL exibir o espaçamento “7 × 7 m a 8 × 8 m”, a classificação “Semi-adensado”, o adensamento “70 a 100 plantas/ha” e a variedade “Hass” em um bloco de informações agronômicas com rótulos inequívocos.

#### Scenario: Consultar os detalhes do pomar
- **WHEN** o usuário visualiza o bloco de cultivo
- **THEN** o sistema associa cada valor ao respectivo rótulo Espaçamento, Classificação, Adensamento e Variedade

### Requirement: Ilustrar o cultivo com o asset de avocado
O aplicativo SHALL incorporar `assets/images/lichia.png` ao resumo visual do cultivo de forma proporcional, sem distorção e com identificação semântica equivalente a “Avocado”.

#### Scenario: Exibir a ilustração em largura reduzida
- **WHEN** a tela é renderizada em um dispositivo estreito
- **THEN** a ilustração se adapta ao espaço disponível sem cortar informações textuais essenciais nem causar rolagem horizontal

#### Scenario: Asset indisponível
- **WHEN** a ilustração não pode ser carregada
- **THEN** o restante do painel continua utilizável sem erro de layout

### Requirement: Exibir o mapa da fazenda e da Zona A
O aplicativo SHALL apresentar um mapa interativo no Inventário com os polígonos do limite da fazenda e da zona identificada pelo código `A` ou nome “Zona A”, utilizando distinção visual e legenda para cada área, sem exibir marcadores ou agrupamentos de plantas.

#### Scenario: Polígonos disponíveis
- **WHEN** o limite da fazenda e a região da Zona A são carregados com ao menos três coordenadas válidas cada
- **THEN** o mapa desenha os dois polígonos, identifica-os visualmente na legenda e ajusta a câmera para manter as áreas disponíveis visíveis

#### Scenario: Apenas um polígono está disponível
- **WHEN** somente o limite da fazenda ou somente a região da Zona A possui coordenadas suficientes
- **THEN** o mapa permanece utilizável, enquadra o polígono disponível e informa de forma não bloqueante que parte dos limites não pôde ser exibida

#### Scenario: Nenhum polígono está disponível
- **WHEN** não há coordenadas suficientes para desenhar qualquer dos dois polígonos
- **THEN** o mapa abre em uma posição padrão e o sistema informa que os limites da propriedade estão indisponíveis

#### Scenario: Visualizar o mapa do Inventário
- **WHEN** o mapa do Inventário conclui o carregamento
- **THEN** nenhum registro de planta é representado por marcador ou cluster

### Requirement: Comunicar o estado dos dados do Inventário
O aplicativo SHALL manter os blocos independentes utilizáveis durante carregamento ou falha parcial e SHALL oferecer uma ação para tentar novamente quando os totais ou dados geográficos não puderem ser obtidos.

#### Scenario: Carregamento inicial
- **WHEN** os totais e limites geográficos estão sendo consultados
- **THEN** a tela preserva sua estrutura e apresenta indicadores de carregamento nos blocos ainda pendentes

#### Scenario: Falha ao carregar os totais
- **WHEN** a consulta das contagens de plantas falha
- **THEN** os dados cadastrais continuam visíveis e o bloco de indicadores apresenta uma mensagem de erro com ação para tentar novamente

#### Scenario: Falha parcial dos dados geográficos
- **WHEN** os totais são carregados mas o limite da fazenda ou a Zona A falha
- **THEN** os indicadores permanecem visíveis e o bloco do mapa comunica a indisponibilidade com ação para tentar novamente

### Requirement: Manter legibilidade e acessibilidade responsivas
O aplicativo SHALL organizar o conteúdo em blocos com contraste suficiente, hierarquia tipográfica, sombras discretas e espaçamento consistente, adaptando a composição sem sobreposição ou rolagem horizontal a larguras móveis a partir de 320 px.

#### Scenario: Usar dispositivo estreito
- **WHEN** a largura disponível é de 320 px
- **THEN** textos, indicadores, imagem, detalhes e mapa permanecem legíveis, alcançáveis por rolagem vertical e sem conteúdo sobreposto

#### Scenario: Usar recursos de acessibilidade
- **WHEN** o usuário navega com leitor de tela ou aumenta a escala de texto
- **THEN** os indicadores preservam rótulo e valor compreensíveis, a imagem possui descrição semântica e o conteúdo pode se reorganizar sem perder informação

