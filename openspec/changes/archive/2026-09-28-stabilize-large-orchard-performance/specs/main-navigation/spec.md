## ADDED Requirements

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
