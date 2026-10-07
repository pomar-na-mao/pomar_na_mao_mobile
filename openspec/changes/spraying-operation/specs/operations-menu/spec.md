## MODIFIED Requirements

### Requirement: Disponibilizar somente Inspecao

O aplicativo SHALL apresentar Inspecao e Pulverizacao como operacoes habilitadas e SHALL apresentar Irrigacao, Colheita e Analise de Solo como operacoes bloqueadas.

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

### Requirement: Abrir a tela de Pulverizacao

O aplicativo SHALL abrir uma tela propria e identificavel de Pulverizacao quando o usuario selecionar o card de Pulverizacao habilitado. A tela SHALL apresentar o mapa e as acoes de pulverizacao dentro da navegacao principal, preservando o destino Operacoes selecionado e as alteracoes salvas localmente.

#### Scenario: Selecionar Pulverizacao
- **WHEN** o usuario toca no card Pulverizacao
- **THEN** o sistema abre uma nova tela com o titulo Pulverizacao, mapa interativo, card de acoes de pulverizacao e oferece a acao padrao de retorno para Operacoes
- **AND** a navegacao inferior permanece visivel com Operacoes selecionado

#### Scenario: Retornar da Pulverizacao
- **WHEN** o usuario aciona o retorno na tela Pulverizacao
- **THEN** o sistema volta a tela Operacoes preservando o destino Operacoes como selecionado
- **AND** os dados da sessao de pulverizacao gravados no banco local permanecem disponiveis para retomada ou sincronizacao
