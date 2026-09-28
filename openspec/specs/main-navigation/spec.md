# main-navigation Specification

## Purpose

Fornecer acesso previsivel as quatro areas principais do aplicativo por meio de uma navegacao inferior persistente e adequada a dispositivos moveis.

## Requirements

### Requirement: Exibir os destinos principais

O aplicativo SHALL exibir uma barra de navegacao inferior com os destinos Inventario, Fazenda, Operacoes e Sobre, nessa ordem, identificados por texto e icone. A barra SHALL permanecer disponivel tambem na tela de Inspecao, com Operacoes selecionado.

#### Scenario: Abertura inicial do aplicativo
- **WHEN** o usuario inicia o aplicativo
- **THEN** o sistema exibe a tela Inventario e marca Inventario como o destino selecionado

#### Scenario: Barra disponivel na area principal
- **WHEN** qualquer um dos quatro destinos principais esta aberto
- **THEN** o sistema mantem visiveis os destinos Inventario, Fazenda, Operacoes e Sobre na barra inferior

#### Scenario: Navegar a partir da Inspecao
- **WHEN** o usuario esta em Inspecao e seleciona outro destino na barra inferior
- **THEN** o aplicativo abre o destino escolhido e atualiza a selecao
- **AND** ao retornar a Operacoes preserva a inspecao aberta e permite continuar suas alteracoes locais

### Requirement: Alternar entre destinos

O aplicativo SHALL trocar o conteudo principal e o estado selecionado da barra quando o usuario escolher um destino.

#### Scenario: Abrir a Fazenda
- **WHEN** o usuario seleciona Fazenda na barra inferior
- **THEN** o sistema exibe a tela Fazenda e marca Fazenda como selecionada

#### Scenario: Abrir Operacoes
- **WHEN** o usuario seleciona Operacoes na barra inferior
- **THEN** o sistema exibe a tela Operacoes e marca Operacoes como selecionada

#### Scenario: Abrir o Sobre
- **WHEN** o usuario seleciona Sobre na barra inferior
- **THEN** o sistema exibe a tela Sobre e marca Sobre como selecionada

#### Scenario: Retornar ao Inventario
- **WHEN** o usuario seleciona Inventario na barra inferior
- **THEN** o sistema exibe a tela Inventario e marca Inventario como selecionado

### Requirement: Manter navegacao durante operacoes de dados

O aplicativo SHALL manter a barra inferior e os destinos independentes utilizaveis durante carga ou atualizacao de dados. Progresso e erros SHALL ser apresentados no contexto da operacao; apenas acoes conflitantes com uma gravacao em andamento SHALL ficar temporariamente indisponiveis.

#### Scenario: Navegar durante Carregar plantas
- **WHEN** o usuario inicia Carregar plantas e seleciona Sobre ou Inventario
- **THEN** a navegacao responde sem esperar a carga terminar e a ultima revisao completa permanece disponivel

#### Scenario: Rede nao responde
- **WHEN** uma requisicao de leitura nao termina dentro do prazo configurado de 30 segundos
- **THEN** a operacao exibe erro recuperavel e permite nova tentativa sem bloquear a navegacao, sem publicar resultado tardio e sem remover o cache anterior

### Requirement: Preservar estado ao suspender recursos de tela

O aplicativo SHALL manter no maximo um mapa nativo montado no estado estavel de foreground e nenhum em background apos a suspensao. Recursos de GPS SHALL existir somente enquanto uma tela visivel necessita de localizacao. Filtros, camera, selecao e rota de Inspecao SHALL ser preservados ao alternar destinos; trabalho local confirmado SHALL sobreviver a encerramento do processo.

#### Scenario: Sair da Fazenda e retomar
- **WHEN** o usuario sai da Fazenda, coloca o app em background e retorna
- **THEN** o mapa anterior nao continua recebendo atualizacoes em background e o destino retomado restaura seu estado sem subscriptions duplicadas

#### Scenario: Resposta atrasada apos sair da tela
- **WHEN** um carregamento ou comando de camera antigo termina depois que sua tela ou controlador foi descartado
- **THEN** seu resultado nao altera a nova tela, nao usa controlador descartado e nao gera excecao nao tratada

#### Scenario: Reabrir apos encerramento
- **WHEN** o processo e encerrado depois de confirmar uma alteracao local de Inspecao
- **THEN** a alteracao e a fila pendente permanecem disponiveis na reabertura, independentemente da reconstrucao dos mapas

### Requirement: Disponibilizar telas iniciais reservadas

O aplicativo SHALL fornecer telas acessiveis e identificaveis para Inventario e Sobre, mesmo sem funcionalidades de dominio adicionais nesta versao.

#### Scenario: Visualizar tela reservada
- **WHEN** o usuario abre Inventario ou Sobre
- **THEN** o sistema exibe a identificacao do destino sem apresentar erro ou conteudo ficticio obrigatorio
