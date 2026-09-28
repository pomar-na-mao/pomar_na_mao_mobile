# farm-map Specification

## Purpose

Permitir que o usuario visualize no mapa a distribuicao geografica das plantas cadastradas na fazenda e sua propria posicao quando disponivel.

## Requirements

### Requirement: Exibir o mapa da fazenda

O aplicativo SHALL apresentar um mapa Google interativo como conteudo principal do destino Fazenda.

#### Scenario: Abrir a Fazenda
- **WHEN** o usuario seleciona o destino Fazenda
- **THEN** o sistema exibe o mapa e informa visualmente enquanto os dados das plantas estao sendo carregados

### Requirement: Carregar plantas cadastradas

O aplicativo SHALL disponibilizar no mapa a totalidade dos registros de `public.plants` do projeto configurado a partir do cache local compartilhado, processando carga e decodificacao fora da thread principal de interface. Quando ainda nao existir uma versao local, SHALL realizar uma unica inicializacao remota paginada ate a exaustao da tabela; quando existir cache, abrir ou tentar novamente na Fazenda SHALL NOT consultar `plants` remotamente. Atualizacoes posteriores SHALL ser recebidas do carregamento explicito realizado na Inspecao.

#### Scenario: Primeira carga sem cache
- **WHEN** a Fazenda precisa das plantas e nenhuma versao local foi inicializada
- **THEN** o sistema obtem todos os registros disponiveis em paginas, persiste o conjunto completo e o disponibiliza para o mapa sem travar a interface

#### Scenario: Consulta concluida com plantas
- **WHEN** existe um conjunto local de plantas com registros
- **THEN** o sistema disponibiliza a totalidade desse conjunto para o mapa sem enviar nova consulta HTTP a `plants`

#### Scenario: Consulta concluida sem plantas
- **WHEN** o cache contem uma versao completa e confirmada sem registros
- **THEN** o sistema mantem o mapa utilizavel, informa que nenhuma planta foi encontrada e nao repete automaticamente a consulta remota

#### Scenario: Falha ao carregar plantas
- **WHEN** a inicializacao remota falha sem existir cache de plantas utilizavel
- **THEN** o sistema mantem a tela Fazenda estavel e apresenta uma mensagem de erro com uma acao para tentar novamente

#### Scenario: Inspecao atualiza as plantas
- **WHEN** o carregamento explicito da Inspecao publica uma nova versao do conjunto de plantas
- **THEN** a Fazenda passa a representar essa versao sem iniciar uma atualizacao remota propria

### Requirement: Representar todas as plantas no mapa

O aplicativo SHALL representar geograficamente a totalidade das plantas carregadas atraves de agrupamento inteligente em niveis de zoom distantes e marcadores individuais em niveis de zoom aproximados, mantendo interacoes de camera e navegacao fluidas sem travamento.

#### Scenario: Plotar multiplas plantas
- **WHEN** duas ou mais plantas sao carregadas com sucesso
- **THEN** o mapa exibe as plantas sem omitir registros, agrupando-as visualmente com contagem em zoom panoramico e desdobrando-as em marcadores individuais nas respectivas coordenadas quando aproximado o zoom

#### Scenario: Identificar uma planta
- **WHEN** o usuario toca no marcador de uma planta
- **THEN** o sistema identifica a planta utilizando ao menos seu `id`

### Requirement: Atualizar representacao por viewport e revisao

O mapa SHALL representar a revisao atual conforme viewport e zoom, respeitando o limite visual de `runtime-stability`, com contagens corretas nos agrupamentos. Plantas fora da viewport SHALL permanecer disponiveis ao mover a camera. Mudancas de conteudo SHALL atualizar a representacao mesmo quando a quantidade total permanecer igual, e eventos somente de GPS SHALL NOT recalcular a camada inteira de plantas nem reenquadrar a camera.

#### Scenario: Navegar em propriedade extensa
- **WHEN** o usuario move a camera para uma area anteriormente fora da tela
- **THEN** as plantas dessa area aparecem individualmente ou agrupadas sem depender de nova consulta remota

#### Scenario: Revisao muda sem alterar total
- **WHEN** uma nova revisao muda coordenadas ou non_existent de uma planta sem mudar o total
- **THEN** posicao e aparencia do marcador passam a refletir a nova revisao

#### Scenario: GPS atualiza continuamente
- **WHEN** a localizacao muda sem alteracao de viewport, filtros ou revisao
- **THEN** somente a representacao de localizacao e informacoes dependentes dela sao atualizadas e a camera escolhida pelo usuario permanece preservada

### Requirement: Solicitar e exibir a posicao do usuario

O aplicativo SHALL solicitar a permissao de localizacao em tempo de execucao e SHALL exibir a posicao atual do usuario no mapa quando o servico, a permissao e uma posicao valida estiverem disponiveis.

#### Scenario: Localizacao autorizada
- **WHEN** o servico de localizacao esta ativo, o usuario concede a permissao e uma posicao e obtida
- **THEN** o mapa indica a posicao atual do usuario

#### Scenario: Permissao negada
- **WHEN** o usuario nega a permissao de localizacao
- **THEN** o sistema mantem as plantas visiveis e informa que a posicao do usuario nao pode ser exibida

#### Scenario: Servico de localizacao indisponivel
- **WHEN** o servico de localizacao esta desativado ou uma posicao nao pode ser obtida
- **THEN** o sistema mantem as plantas visiveis e informa a indisponibilidade da posicao do usuario

### Requirement: Ajustar a visualizacao a dados disponiveis

O aplicativo SHALL escolher uma regiao inicial util usando as coordenadas disponiveis das plantas ou do usuario e SHALL utilizar uma regiao padrao configurada quando nenhuma coordenada estiver disponivel.

#### Scenario: Existem plantas carregadas
- **WHEN** o mapa recebe uma ou mais plantas
- **THEN** a camera apresenta uma regiao que permite localizar as plantas carregadas

#### Scenario: Nao existem coordenadas disponiveis
- **WHEN** nao ha plantas e a posicao do usuario nao esta disponivel
- **THEN** o mapa abre em uma regiao padrao sem falhar
