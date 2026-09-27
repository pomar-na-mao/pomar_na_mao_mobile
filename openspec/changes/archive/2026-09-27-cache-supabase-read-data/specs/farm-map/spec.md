## MODIFIED Requirements

### Requirement: Carregar plantas cadastradas
O aplicativo SHALL disponibilizar no mapa a totalidade dos registros de `public.plants` do projeto configurado a partir do cache local compartilhado, processando carga e decodificação fora da thread principal de interface. Quando ainda não existir uma versão local, SHALL realizar uma única inicialização remota paginada até a exaustão da tabela; quando existir cache, abrir ou tentar novamente na Fazenda SHALL NOT consultar `plants` remotamente. Atualizações posteriores SHALL ser recebidas do carregamento explícito realizado na Inspeção.

#### Scenario: Primeira carga sem cache
- **WHEN** a Fazenda precisa das plantas e nenhuma versão local foi inicializada
- **THEN** o sistema obtém todos os registros disponíveis em páginas, persiste o conjunto completo e o disponibiliza para o mapa sem travar a interface

#### Scenario: Consulta concluída com plantas
- **WHEN** existe um conjunto local de plantas com registros
- **THEN** o sistema disponibiliza a totalidade desse conjunto para o mapa sem enviar nova consulta HTTP a `plants`

#### Scenario: Consulta concluída sem plantas
- **WHEN** o cache contém uma versão completa e confirmada sem registros
- **THEN** o sistema mantém o mapa utilizável, informa que nenhuma planta foi encontrada e não repete automaticamente a consulta remota

#### Scenario: Falha ao carregar plantas
- **WHEN** a inicialização remota falha sem existir cache de plantas utilizável
- **THEN** o sistema mantém a tela Fazenda estável e apresenta uma mensagem de erro com uma ação para tentar novamente

#### Scenario: Inspeção atualiza as plantas
- **WHEN** o carregamento explícito da Inspeção publica uma nova versão do conjunto de plantas
- **THEN** a Fazenda passa a representar essa versão sem iniciar uma atualização remota própria
