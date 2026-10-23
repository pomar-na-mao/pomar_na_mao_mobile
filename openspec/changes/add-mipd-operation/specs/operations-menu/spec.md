## MODIFIED Requirements

### Requirement: Apresentar o catalogo de operacoes

O aplicativo SHALL exibir na tela Operacoes os cards Inspecao, Pulverizacao, MIPD, Irrigacao, Colheita e Analise de Solo, cada um identificado por nome e icone visualmente coerente com sua finalidade. O card MIPD SHALL aparecer imediatamente abaixo ou depois de Pulverizacao na ordem responsiva do catalogo.

#### Scenario: Abrir o catalogo de operacoes
- **WHEN** o usuario seleciona Operacoes na navegacao principal
- **THEN** o sistema exibe os seis cards de operacao com seus respectivos nomes e icones
- **AND** MIPD aparece imediatamente depois de Pulverizacao na ordem de leitura

### Requirement: Disponibilizar somente Inspecao

O aplicativo SHALL apresentar Inspecao, Pulverizacao e MIPD como operacoes habilitadas e SHALL apresentar Irrigacao, Colheita e Analise de Solo como operacoes bloqueadas.

#### Scenario: Identificar uma operacao bloqueada
- **WHEN** o usuario visualiza Irrigacao, Colheita ou Analise de Solo
- **THEN** o card correspondente exibe indicador visual e textual de indisponibilidade sem depender apenas da cor

#### Scenario: Tentar abrir uma operacao bloqueada
- **WHEN** o usuario toca em Irrigacao, Colheita ou Analise de Solo
- **THEN** o sistema permanece na tela Operacoes e nao executa navegacao

#### Scenario: Tecnologia assistiva encontra uma operacao bloqueada
- **WHEN** uma tecnologia assistiva percorre um card bloqueado
- **THEN** o sistema anuncia o nome da operacao e seu estado indisponivel ou desabilitado

### Requirement: Agrupar operacoes futuras com estado legivel

A tela Operacoes SHALL agrupar Irrigacao, Colheita e Analise de Solo como operacoes futuras, mantendo-as visiveis no catalogo com status textual, descricao curta e affordance desabilitada. O estado indisponivel SHALL ser perceptivel por texto, semantica e tratamento visual, sem depender apenas de cor.

#### Scenario: Visualizar operacoes futuras
- **WHEN** o usuario visualiza o catalogo de operacoes
- **THEN** Irrigacao, Colheita e Analise de Solo aparecem agrupadas como futuras ou indisponiveis
- **AND** cada item informa seu nome, status e descricao curta sem sugerir que pode ser aberto imediatamente

#### Scenario: Usar tecnologia assistiva em operacao futura
- **WHEN** uma tecnologia assistiva percorre uma operacao futura
- **THEN** o sistema anuncia o nome da operacao e seu estado indisponivel ou em breve

#### Scenario: Tocar em operacao futura
- **WHEN** o usuario toca em uma operacao futura
- **THEN** o sistema permanece na tela Operacoes e nao executa navegacao

## ADDED Requirements

### Requirement: Abrir a tela de MIPD

O aplicativo SHALL abrir uma tela propria e identificavel de MIPD quando o usuario selecionar o card habilitado. A tela SHALL apresentar mapa e acoes dentro da navegacao principal, preservar Operacoes como destino selecionado e manter as marcacoes salvas localmente ao retornar.

#### Scenario: Selecionar MIPD
- **WHEN** o usuario toca no card MIPD
- **THEN** o sistema abre uma tela com titulo MIPD, mapa, card de acoes e retorno para Operacoes
- **AND** a navegacao inferior permanece visivel com Operacoes selecionado

#### Scenario: Retornar do MIPD
- **WHEN** o usuario aciona o retorno na tela MIPD
- **THEN** o sistema volta a tela Operacoes com o destino Operacoes selecionado
- **AND** as marcacoes persistidas no SQLite permanecem disponiveis para retomada

