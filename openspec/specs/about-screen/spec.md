# about-screen Specification

## Purpose

Apresentar informações institucionais da Pomar na mão e da parceira Prímora dentro da tela Sobre, com uma composição visual clara, agradável e adequada a dispositivos móveis.

## Requirements

### Requirement: Exibir conteúdo institucional da tela Sobre
O aplicativo SHALL apresentar uma tela Sobre com conteúdo institucional visível sobre a Pomar na mão e a Prímora.

#### Scenario: Abrir a tela Sobre
- **WHEN** o usuário seleciona o destino Sobre na navegação inferior
- **THEN** o sistema exibe uma tela identificada como Sobre com conteúdo institucional

### Requirement: Apresentar a Pomar na mão
O aplicativo SHALL explicar que a Pomar na mão é uma empresa dedicada a mudar a gestão de pomares por meio de controle fino, agricultura de precisão e inteligência artificial, possibilitando melhor uso de recursos, maior controle e gerar economia no dia a dia dos pomares.

#### Scenario: Visualizar a seção Pomar na mão
- **WHEN** o usuário abre a tela Sobre
- **THEN** o sistema apresenta o nome Pomar na mão e sua descrição institucional

### Requirement: Apresentar a Prímora como parceira
O aplicativo SHALL explicar que a Prímora é uma consultoria agrícola com especialidade em gerenciamento e inteligência de dados.

#### Scenario: Visualizar a seção Prímora
- **WHEN** o usuário abre a tela Sobre
- **THEN** o sistema apresenta o nome Prímora e sua descrição institucional como parceira

### Requirement: Fornecer layout móvel agradável e legível
O aplicativo SHALL organizar o conteúdo da tela Sobre com espaçamento, hierarquia visual e contraste suficientes para leitura em dispositivos móveis.

#### Scenario: Conteúdo maior que a tela
- **WHEN** o conteúdo da tela Sobre excede a altura disponível do dispositivo
- **THEN** o sistema permite rolagem sem cortar informações

#### Scenario: Exibição sem dependências externas
- **WHEN** o usuário abre a tela Sobre sem conexão de rede
- **THEN** o sistema exibe o conteúdo institucional sem erro ou estado de carregamento remoto
