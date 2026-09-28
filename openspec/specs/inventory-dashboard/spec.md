# inventory-dashboard Specification

## Purpose

Oferecer uma visao consolidada, legivel e responsiva do inventario do pomar, dos parametros de cultivo e da area geografica da propriedade.

## Requirements

### Requirement: Apresentar o resumo da propriedade

O aplicativo SHALL apresentar no destino Inventario o nome "Sitio Sao Francisco", a area total "54 ha" e o cultivo "Avocado" como informacoes de destaque da propriedade.

#### Scenario: Abrir o Inventario
- **WHEN** o usuario acessa o destino Inventario
- **THEN** o sistema identifica a propriedade como "Sitio Sao Francisco" e exibe sua area total e seu cultivo sem exigir interacao adicional

### Requirement: Contabilizar as plantas por disponibilidade

O aplicativo SHALL exibir os totais exatos da revisao completa do cache compartilhado para `non_existent = false` como "Plantas existentes" e `non_existent = true` como "Disponiveis para plantio". Na ausencia de cache SHALL usar a inicializacao compartilhada prevista em `local-read-cache`; reabrir ou tentar novamente SHALL NOT consultar contagens remotas proprias. Totais SHALL ser derivados ou persistidos por revisao sem exigir hidratacao integral das plantas a cada abertura do Inventario.

#### Scenario: Existem plantas nas duas categorias
- **WHEN** a revisao local contem registros com `non_existent = false` e com `non_existent = true`
- **THEN** o sistema apresenta em indicadores distintos o total exato de cada categoria da mesma revisao

#### Scenario: Uma categoria nao possui registros
- **WHEN** uma categoria possui zero registros na revisao completa
- **THEN** o indicador apresenta zero sem tratar o resultado como erro

#### Scenario: Os dados mudam antes de uma nova carga
- **WHEN** apenas a fonte remota muda e o usuario reabre ou tenta novamente no Inventario
- **THEN** o sistema continua exibindo a revisao local ate a atualizacao explicita de plantas na Inspecao

#### Scenario: Publicar nova revisao
- **WHEN** a atualizacao explicita publica um novo cache completo
- **THEN** os indicadores passam a representar essa revisao sem consultas remotas adicionais

#### Scenario: Cache ainda ausente
- **WHEN** o Inventario abre sem uma revisao local completa
- **THEN** os indicadores mostram carregamento local ao bloco e participam da inicializacao compartilhada sem impedir a navegacao

### Requirement: Exibir os parametros de cultivo

O aplicativo SHALL exibir o espacamento "7 x 7 m a 8 x 8 m", a classificacao "Semi-adensado", o adensamento "70 a 100 plantas/ha" e a variedade "Hass" em um bloco de informacoes agronomicas com rotulos inequivocos.

#### Scenario: Consultar os detalhes do pomar
- **WHEN** o usuario visualiza o bloco de cultivo
- **THEN** o sistema associa cada valor ao respectivo rotulo Espacamento, Classificacao, Adensamento e Variedade

### Requirement: Ilustrar o cultivo com o asset de avocado

O aplicativo SHALL incorporar `assets/images/lichia.png` ao resumo visual do cultivo de forma proporcional, sem distorcao e com identificacao semantica equivalente a "Avocado".

#### Scenario: Exibir a ilustracao em largura reduzida
- **WHEN** a tela e renderizada em um dispositivo estreito
- **THEN** a ilustracao se adapta ao espaco disponivel sem cortar informacoes textuais essenciais nem causar rolagem horizontal

#### Scenario: Asset indisponivel
- **WHEN** a ilustracao nao pode ser carregada
- **THEN** o restante do painel continua utilizavel sem erro de layout

### Requirement: Exibir o mapa da fazenda e da Zona A

O aplicativo SHALL apresentar um mapa interativo no Inventario com os poligonos do limite da fazenda e da zona identificada pelo codigo `A` ou nome "Zona A", utilizando distincao visual e legenda para cada area, sem exibir marcadores ou agrupamentos de plantas.

#### Scenario: Poligonos disponiveis
- **WHEN** o limite da fazenda e a regiao da Zona A sao carregados com ao menos tres coordenadas validas cada
- **THEN** o mapa desenha os dois poligonos, identifica-os visualmente na legenda e ajusta a camera para manter as areas disponiveis visiveis

#### Scenario: Apenas um poligono esta disponivel
- **WHEN** somente o limite da fazenda ou somente a regiao da Zona A possui coordenadas suficientes
- **THEN** o mapa permanece utilizavel, enquadra o poligono disponivel e informa de forma nao bloqueante que parte dos limites nao pode ser exibida

#### Scenario: Nenhum poligono esta disponivel
- **WHEN** nao ha coordenadas suficientes para desenhar qualquer dos dois poligonos
- **THEN** o mapa abre em uma posicao padrao e o sistema informa que os limites da propriedade estao indisponiveis

#### Scenario: Visualizar o mapa do Inventario
- **WHEN** o mapa do Inventario conclui o carregamento
- **THEN** nenhum registro de planta e representado por marcador ou cluster

### Requirement: Comunicar o estado dos dados do Inventario

O aplicativo SHALL manter os blocos independentes utilizaveis durante carregamento ou falha parcial e SHALL oferecer uma acao para tentar novamente quando os totais ou dados geograficos nao puderem ser obtidos.

#### Scenario: Carregamento inicial
- **WHEN** os totais e limites geograficos estao sendo consultados
- **THEN** a tela preserva sua estrutura e apresenta indicadores de carregamento nos blocos ainda pendentes

#### Scenario: Falha ao carregar os totais
- **WHEN** a consulta das contagens de plantas falha
- **THEN** os dados cadastrais continuam visiveis e o bloco de indicadores apresenta uma mensagem de erro com acao para tentar novamente

#### Scenario: Falha parcial dos dados geograficos
- **WHEN** os totais sao carregados mas o limite da fazenda ou a Zona A falha
- **THEN** os indicadores permanecem visiveis e o bloco do mapa comunica a indisponibilidade com acao para tentar novamente

### Requirement: Manter legibilidade e acessibilidade responsivas

O aplicativo SHALL organizar o conteudo em blocos com contraste suficiente, hierarquia tipografica, sombras discretas e espacamento consistente, adaptando a composicao sem sobreposicao ou rolagem horizontal a larguras moveis a partir de 320 px.

#### Scenario: Usar dispositivo estreito
- **WHEN** a largura disponivel e de 320 px
- **THEN** textos, indicadores, imagem, detalhes e mapa permanecem legiveis, alcancaveis por rolagem vertical e sem conteudo sobreposto

#### Scenario: Usar recursos de acessibilidade
- **WHEN** o usuario navega com leitor de tela ou aumenta a escala de texto
- **THEN** os indicadores preservam rotulo e valor compreensiveis, a imagem possui descricao semantica e o conteudo pode se reorganizar sem perder informacao
