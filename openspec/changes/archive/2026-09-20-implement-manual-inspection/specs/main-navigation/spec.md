## MODIFIED Requirements

### Requirement: Exibir os destinos principais
O aplicativo SHALL exibir uma barra de navegação inferior com os destinos Inventário, Fazenda, Operações e Sobre, nessa ordem, identificados por texto e ícone. A barra SHALL permanecer disponível também na tela de Inspeção, com Operações selecionado.

#### Scenario: Abertura inicial do aplicativo
- **WHEN** o usuário inicia o aplicativo
- **THEN** o sistema exibe a tela Inventário e marca Inventário como o destino selecionado

#### Scenario: Barra disponível na área principal
- **WHEN** qualquer um dos quatro destinos principais está aberto
- **THEN** o sistema mantém visíveis os destinos Inventário, Fazenda, Operações e Sobre na barra inferior

#### Scenario: Navegar a partir da Inspeção
- **WHEN** o usuário está em Inspeção e seleciona outro destino na barra inferior
- **THEN** o aplicativo abre o destino escolhido e atualiza a seleção
- **AND** ao retornar a Operações preserva a inspeção aberta e permite continuar suas alterações locais
