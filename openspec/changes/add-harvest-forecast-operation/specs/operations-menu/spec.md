## MODIFIED Requirements

### Requirement: Apresentar o catalogo de operacoes

O aplicativo SHALL exibir na tela Operacoes, dentro do módulo **Rotina do pomar**, os cards **Ocorrências**, **MIPD**, **Atividade**, **Estoque**, **Previsão de Safra** e **Coletas agronômicas** (com **Previsão de Safra** imediatamente depois de **Estoque**), e no módulo **Gestão da produção**, os cards **Pulverização**, **Irrigação**, **Colheita**, **Análise de solo** e **Planejamento de atividades**, cada um identificado por nome, descrição e ícone visualmente coerente com sua finalidade.

#### Scenario: Abrir o catalogo de operacoes
- **WHEN** o usuario seleciona Operacoes na navegacao principal
- **THEN** o módulo **Rotina do pomar** exibe os cards na ordem: **Ocorrências**, **MIPD**, **Atividade**, **Estoque**, **Previsão de Safra** e **Coletas agronômicas**
- **AND** o card **Previsão de Safra** aparece imediatamente depois de **Estoque**

### Requirement: Disponibilizar somente Inspecao

O aplicativo SHALL apresentar **Ocorrências**, **MIPD**, **Atividade**, **Estoque**, **Previsão de Safra** e **Pulverização** como operações habilitadas e SHALL apresentar **Coletas agronômicas**, **Irrigação**, **Colheita**, **Análise de solo** e **Planejamento de atividades** como operações bloqueadas.

#### Scenario: Identificar uma operacao bloqueada
- **WHEN** o usuario visualiza Coletas agronômicas, Irrigacao, Colheita, Analise de Solo ou Planejamento de atividades
- **THEN** o card correspondente exibe indicador visual e textual de indisponibilidade sem depender apenas da cor

#### Scenario: Tentar abrir uma operacao bloqueada
- **WHEN** o usuario toca em uma operacao bloqueada
- **THEN** o sistema permanece na tela Operacoes e nao executa navegacao

#### Scenario: Tecnologia assistiva encontra uma operacao bloqueada
- **WHEN** uma tecnologia assistiva percorre um card bloqueado
- **THEN** o sistema anuncia o nome da operacao e seu estado indisponivel ou desabilitado

#### Scenario: Identificar Previsão de Safra como operação habilitada
- **WHEN** o usuário visualiza o card **Previsão de Safra** em **Rotina do pomar**
- **THEN** o card é exibido como habilitado e disponível para toque

## ADDED Requirements

### Requirement: Abrir a tela de Previsão de Safra

O aplicativo SHALL abrir uma tela própria e identificável de **Previsão de Safra** quando o usuário selecionar o card habilitado **Previsão de Safra** em **Rotina do pomar**, preservando o destino **Operações** selecionado e os registros salvos localmente ao retornar.

#### Scenario: Selecionar Previsão de Safra
- **WHEN** o usuário toca no card **Previsão de Safra**
- **THEN** o sistema abre a tela **Previsão de Safra** com o mapa, os 5 botões circulares (`N`, `P`, `M`, `G`, `GG`) e o card inferior com **Carregar plantas** e **Marcações salvas**

#### Scenario: Retornar da Previsão de Safra
- **WHEN** o usuário aciona o retorno na tela **Previsão de Safra**
- **THEN** o sistema volta à tela **Operações** mantendo as marcações salvas no SQLite disponíveis para consulta, edição, exclusão ou sincronização
