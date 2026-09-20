# main-navigation Specification

## Purpose

Fornecer acesso previsível às três áreas principais do aplicativo por meio de uma navegação inferior persistente e adequada a dispositivos móveis.

## Requirements

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

### Requirement: Disponibilizar telas iniciais reservadas
O aplicativo SHALL fornecer telas acessíveis e identificáveis para Inventário e Sobre, mesmo sem funcionalidades de domínio adicionais nesta versão.

#### Scenario: Visualizar tela reservada
- **WHEN** o usuário abre Inventário ou Sobre
- **THEN** o sistema exibe a identificação do destino sem apresentar erro ou conteúdo fictício obrigatório
