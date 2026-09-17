## MODIFIED Requirements

### Requirement: Exibir os destinos principais
O aplicativo SHALL exibir uma barra de navegação inferior com os destinos Inventário, Fazenda, Operações e Sobre, nessa ordem, identificados por texto e ícone.

#### Scenario: Abertura inicial do aplicativo
- **WHEN** o usuário inicia o aplicativo
- **THEN** o sistema exibe a tela Inventário e marca Inventário como o destino selecionado

#### Scenario: Barra disponível na área principal
- **WHEN** qualquer um dos quatro destinos principais está aberto
- **THEN** o sistema mantém visíveis os destinos Inventário, Fazenda, Operações e Sobre na barra inferior

### Requirement: Alternar entre destinos
O aplicativo SHALL trocar o conteúdo principal e o estado selecionado da barra quando o usuário escolher um destino.

#### Scenario: Abrir a Fazenda
- **WHEN** o usuário seleciona Fazenda na barra inferior
- **THEN** o sistema exibe a tela Fazenda e marca Fazenda como selecionada

#### Scenario: Abrir Operações
- **WHEN** o usuário seleciona Operações na barra inferior
- **THEN** o sistema exibe a tela Operações e marca Operações como selecionada

#### Scenario: Abrir o Sobre
- **WHEN** o usuário seleciona Sobre na barra inferior
- **THEN** o sistema exibe a tela Sobre e marca Sobre como selecionada

#### Scenario: Retornar ao Inventário
- **WHEN** o usuário seleciona Inventário na barra inferior
- **THEN** o sistema exibe a tela Inventário e marca Inventário como selecionado
