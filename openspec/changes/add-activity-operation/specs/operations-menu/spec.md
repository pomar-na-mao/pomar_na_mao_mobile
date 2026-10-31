## MODIFIED Requirements

### Requirement: Apresentar o catalogo de operacoes

O aplicativo SHALL exibir na tela Operacoes os cards Inspecao, Pulverizacao, MIPD, Atividade, Irrigacao, Colheita e Analise de Solo, cada um identificado por nome e icone visualmente coerente com sua finalidade. Atividade SHALL aparecer imediatamente depois de MIPD na ordem responsiva do catalogo.

#### Scenario: Abrir o catalogo de operacoes
- **WHEN** o usuario seleciona Operacoes na navegacao principal
- **THEN** o sistema exibe os sete cards de operacao com seus respectivos nomes e icones
- **AND** Atividade aparece imediatamente depois de MIPD na ordem de leitura

### Requirement: Disponibilizar somente Inspecao

O aplicativo SHALL apresentar Inspecao, Pulverizacao, MIPD e Atividade como operacoes habilitadas e SHALL apresentar Irrigacao, Colheita e Analise de Solo como operacoes bloqueadas.

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

### Requirement: Abrir a tela da Atividade

O aplicativo SHALL abrir uma tela própria e identificável da Atividade quando o usuário selecionar o card habilitado. A tela SHALL apresentar mapa, plantas e ações de desenho dentro da navegação principal, preservar Operações como destino selecionado e manter os lançamentos salvos localmente ao retornar.

#### Scenario: Selecionar Atividade
- **WHEN** o usuário toca no card Atividade
- **THEN** o sistema abre uma tela com títula Atividade, mapa, controles de desenho e retorno para Operações
- **AND** a navegação inferior permanece visível com Operações selecionado

#### Scenario: Retornar da Atividade
- **WHEN** o usuário aciona o retorno na tela Atividade
- **THEN** o sistema volta à tela Operações com o destino Operações selecionado
- **AND** os lançamentos persistidos localmente permanecem disponíveis para consulta ou sincronização

