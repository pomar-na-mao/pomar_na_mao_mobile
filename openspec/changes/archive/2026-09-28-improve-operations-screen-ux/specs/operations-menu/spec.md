## ADDED Requirements

### Requirement: Destacar a operacao principal disponivel

A tela Operacoes SHALL apresentar Inspecao como acao principal disponivel, com maior prioridade visual que as operacoes futuras. O destaque SHALL incluir nome, descricao curta, status disponivel e indicacao clara de que o toque abre a rotina.

#### Scenario: Abrir Operacoes com Inspecao disponivel
- **WHEN** o usuario acessa a tela Operacoes
- **THEN** Inspecao aparece como a acao principal disponivel antes ou com maior destaque que as operacoes futuras
- **AND** o card ou bloco de Inspecao comunica que a rotina pode ser aberta

#### Scenario: Selecionar a acao principal
- **WHEN** o usuario toca no destaque de Inspecao
- **THEN** o sistema abre a tela de Inspecao preservando o comportamento de navegacao existente

### Requirement: Agrupar operacoes futuras com estado legivel

A tela Operacoes SHALL agrupar Pulverizacao, Irrigacao, Colheita e Analise de Solo como operacoes futuras, mantendo-as visiveis no catalogo com status textual, descricao curta e affordance desabilitada. O estado indisponivel SHALL ser perceptivel por texto, semantica e tratamento visual, sem depender apenas de cor.

#### Scenario: Visualizar operacoes futuras
- **WHEN** o usuario visualiza o catalogo de operacoes
- **THEN** Pulverizacao, Irrigacao, Colheita e Analise de Solo aparecem agrupadas como futuras ou indisponiveis
- **AND** cada item informa seu nome, status e descricao curta sem sugerir que pode ser aberto imediatamente

#### Scenario: Usar tecnologia assistiva em operacao futura
- **WHEN** uma tecnologia assistiva percorre uma operacao futura
- **THEN** o sistema anuncia o nome da operacao e seu estado indisponivel ou em breve

#### Scenario: Tocar em operacao futura
- **WHEN** o usuario toca em uma operacao futura
- **THEN** o sistema permanece na tela Operacoes e nao executa navegacao

### Requirement: Manter composicao operacional responsiva

A tela Operacoes SHALL usar uma composicao adequada a uso recorrente em campo, com hierarquia compacta, areas de toque acessiveis e sem conteudo sobreposto em larguras moveis a partir de 320 px. A tela SHALL avoid padroes de landing page, hero marketing ou cards decorativos sem funcao operacional.

#### Scenario: Exibir em 320 px
- **WHEN** a tela Operacoes e exibida com largura de 320 px
- **THEN** o resumo, a acao principal e as operacoes futuras permanecem legiveis por rolagem vertical
- **AND** nao ha rolagem horizontal, texto cortado ou sobreposicao de elementos

#### Scenario: Exibir em largura ampla
- **WHEN** a tela Operacoes e exibida em largura ampla
- **THEN** o conteudo usa colunas ou largura limitada para preservar leitura rapida e equilibrio visual

### Requirement: Comunicar contexto operacional sem bloquear a acao

A tela Operacoes SHALL apresentar um resumo curto que ajude o usuario a entender o estado do catalogo sem atrasar o acesso a Inspecao. Esse resumo SHALL permanecer textual, escaneavel e nao devera substituir a acao principal por instrucao longa.

#### Scenario: Ler resumo da tela
- **WHEN** o usuario abre Operacoes
- **THEN** o sistema apresenta um resumo curto do catalogo e da disponibilidade atual das rotinas
- **AND** a acao Inspecao continua acessivel sem depender de leitura extensa
