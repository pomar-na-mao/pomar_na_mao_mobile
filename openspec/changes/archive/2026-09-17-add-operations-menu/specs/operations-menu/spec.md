## Purpose

Fornecer um ponto de acesso claro, agradável e responsivo às rotinas operacionais do pomar, distinguindo ações disponíveis de funcionalidades futuras.

## ADDED Requirements

### Requirement: Apresentar o catálogo de operações
O aplicativo SHALL exibir na tela Operações os cards Inspeção, Pulverização, Irrigação, Colheita e Análise de Solo, cada um identificado por nome e ícone visualmente coerente com sua finalidade.

#### Scenario: Abrir o catálogo de operações
- **WHEN** o usuário seleciona Operações na navegação principal
- **THEN** o sistema exibe os cinco cards de operação com seus respectivos nomes e ícones

### Requirement: Oferecer layout agradável e responsivo
O aplicativo SHALL organizar os cards com hierarquia visual, contraste, espaçamento e dimensões de toque acessíveis, adaptando a quantidade de colunas ao espaço horizontal disponível sem corte ou rolagem horizontal.

#### Scenario: Exibir em largura compacta
- **WHEN** a tela Operações é exibida em uma janela compacta
- **THEN** o sistema apresenta todos os cards em uma composição rolável sem sobreposição ou conteúdo cortado

#### Scenario: Exibir em largura ampla
- **WHEN** a tela Operações é exibida em uma janela ampla
- **THEN** o sistema distribui os cards em mais colunas e limita a largura do conteúdo para preservar legibilidade e equilíbrio visual

### Requirement: Disponibilizar somente Inspeção
O aplicativo SHALL apresentar Inspeção como operação habilitada e SHALL apresentar Pulverização, Irrigação, Colheita e Análise de Solo como operações bloqueadas.

#### Scenario: Identificar uma operação bloqueada
- **WHEN** o usuário visualiza Pulverização, Irrigação, Colheita ou Análise de Solo
- **THEN** o card correspondente exibe indicador visual e textual de indisponibilidade sem depender apenas da cor

#### Scenario: Tentar abrir uma operação bloqueada
- **WHEN** o usuário toca em Pulverização, Irrigação, Colheita ou Análise de Solo
- **THEN** o sistema permanece na tela Operações e não executa navegação

#### Scenario: Tecnologia assistiva encontra uma operação bloqueada
- **WHEN** uma tecnologia assistiva percorre um card bloqueado
- **THEN** o sistema anuncia o nome da operação e seu estado indisponível ou desabilitado

### Requirement: Abrir a tela de Inspeção
O aplicativo SHALL abrir uma tela própria e identificável de Inspeção quando o usuário selecionar o único card habilitado.

#### Scenario: Selecionar Inspeção
- **WHEN** o usuário toca no card Inspeção
- **THEN** o sistema abre uma nova tela com o título Inspeção e oferece a ação padrão de retorno para Operações

#### Scenario: Retornar da Inspeção
- **WHEN** o usuário aciona o retorno na tela Inspeção
- **THEN** o sistema volta à tela Operações preservando o destino Operações como selecionado
