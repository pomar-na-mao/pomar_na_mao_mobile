## Purpose

Permitir o registro e acompanhamento em campo de operacoes de pulverizacao agricola, gravando rotas GPS em tempo real, calculando plantas atingidas com revisao interativa pelo operador, coletando insumos aplicados e sincronizando de forma confiavel e offline-first com o Supabase.

## ADDED Requirements

### Requirement: Exibir interface operacional de pulverizacao

O aplicativo SHALL disponibilizar a tela de Pulverizacao apresentando mapa interativo em tela cheia, localizacao GPS atual do operador, plantas renderizadas conforme filtros ativos e uma barra de acoes no rodape estruturada com 4 botoes principais: Carregar Plantas, Filtrar por Zona, Controle de Sessao e Pulverizacoes Salvas.

#### Scenario: Abertura da tela de pulverizacao
- **WHEN** o usuario acessa a funcionalidade de Pulverizacao
- **THEN** o sistema inicializa o mapa centralizado na posicao atual ou no talhao selecionado, exibe as plantas carregadas e disponibiliza o card de acoes com os quatro botoes operacionais

#### Scenario: Visualizacao sem plantas carregadas
- **WHEN** nenhuma planta estiver carregada em memoria ou cache
- **THEN** o mapa permanece disponivel com indicacao de posicao atual e o botao de carregamento de plantas permanece pronto para acionamento

### Requirement: Carregar plantas no mapa de pulverizacao

O aplicativo SHALL disponibilizar no primeiro botao da barra de acoes o carregamento das plantas cadastradas a partir do armazenamento local ou remoto, exibindo indicador de progresso durante o carregamento e atualizando a contagem total de plantas no mapa.

#### Scenario: Acionar carregamento de plantas
- **WHEN** o usuario toca no botao Carregar Plantas
- **THEN** o sistema exibe feedback de carregamento no botao ou tela e renderiza as plantas correspondentes no mapa apos a conclusao

### Requirement: Filtrar plantas por zona

O aplicativo SHALL disponibilizar no segundo botao da barra de acoes um modal de selecao de zona/talhao, permitindo ao operador filtrar as plantas visiveis e destacar o poligono correspondente da zona no mapa.

#### Scenario: Aplicar filtro de zona
- **WHEN** o usuario seleciona uma zona especifica no modal de filtros e confirma
- **THEN** o mapa ajusta o enquadramento para o poligono da zona e filtra as plantas exibidas para pertencerem exclusivamente a essa zona

### Requirement: Controlar sessao de pulverizacao com iniciar, pausar e finalizar

O aplicativo SHALL disponibilizar no terceiro botao da barra de acoes um modal de controle de sessao de pulverizacao local com as acoes Iniciar, Pausar e Finalizar. A gravacao da rota e sessao deve ocorrer integralmente em modo offline/local.

#### Scenario: Iniciar nova gravacao de pulverizacao
- **WHEN** o usuario toca em Iniciar no modal de sessao
- **THEN** o sistema inicia a contagem de tempo, habilita a captura continua de pontos GPS, altera o estado da sessao para em andamento e fecha o modal

#### Scenario: Pausar gravacao de pulverizacao
- **WHEN** o usuario abre o modal de controle e toca em Pausar durante uma sessao ativa
- **THEN** o sistema suspende temporariamente a adicao de novos pontos GPS a rota e sinaliza o estado pausado

#### Scenario: Retomar gravacao de pulverizacao pausada
- **WHEN** o usuario seleciona Retomar em uma sessao pausada
- **THEN** o sistema volta a capturar pontos GPS e a estender a rota continua no mapa

#### Scenario: Finalizar gravacao de pulverizacao
- **WHEN** o usuario seleciona Finalizar com ao menos dois pontos GPS gravados
- **THEN** o sistema encerra o rastreamento da rota, calcula a distancia total percorrida e transiciona automaticamente para o fluxo de revisao de plantas afetadas

### Requirement: Rastrear e desenhar rota GPS em tempo real

O aplicativo SHALL registrar os pontos geograficos (`latitude`, `longitude`, `speed_mps`, `accuracy_m`, `recorded_at`) durante a sessao ativa, desenhar o traco continuo da rota (polyline/GeoJSON LineString) sobre o mapa e acumular a distancia percorrida em metros.

#### Scenario: Movimentacao durante sessao ativa
- **WHEN** o dispositivo se desloca com GPS ativo durante uma sessao em andamento
- **THEN** cada nova coordenada valida e registrada localmente e a linha da rota e atualizada imediatamente na camada do mapa

### Requirement: Calcular geometricamente plantas afetadas pela rota

Ao finalizar a gravacao da rota, o aplicativo SHALL calcular as plantas localizadas a uma distancia limite configuravel (padrao 9 metros) da rota percorrida ou de seus pontos de rastreamento, espelhando a definicao da RPC `recalculate_operation_affected_plants`, marcando-as inicialmente como `auto_matched`.

#### Scenario: Conclusao de rota com plantas proximas
- **WHEN** o operador finaliza uma rota que passou a menos de 9 metros de plantas cadastradas na zona
- **THEN** o sistema seleciona automaticamente essas plantas como afetadas (`auto_matched`) e as destaca visualmente na tela de revisao

### Requirement: Revisar interativamente plantas afetadas

O aplicativo SHALL permitir ao operador revisar a selecao de plantas afetadas antes de concluir a operacao, possibilitando desmarcar plantas identificadas automaticamente e adicionar/marcar manualmente plantas adicionais no mapa ou lista (`matchSource` como `manual_added`).

#### Scenario: Desmarcar planta autoidentificada
- **WHEN** o operador desmarca uma planta previamente identificada pelo calculo de 9 metros
- **THEN** a planta e removida da lista de confirmadas daquela pulverizacao

#### Scenario: Adicionar planta manualmente
- **WHEN** o operador toca em uma planta nao alcancada pela rota e a inclui na revisao
- **THEN** a planta e associada a pulverizacao com origem `manual_added`

### Requirement: Registrar insumos agricolas e metadados operacionais

Apos a revisao das plantas afetadas, o aplicativo SHALL apresentar modal para preenchimento obrigatorio de operador (`operatorName`), zona de aplicacao e de pelo menos um insumo agricola (`productName`, `inputType`), alem de dados opcionais de maquina (`machineName`), trator (`tractorIdentifier`), dosagem (`dose`, `doseUnit`), quantidade total (`totalQuantity`, `totalQuantityUnit`), ingrediente ativo e observacoes.

#### Scenario: Preenchimento de insumos e metadados validos
- **WHEN** o operador informa operador, ao menos um produto com sua dosagem e confirma
- **THEN** o sistema valida o formulario, associa os insumos e metadados a operacao local e grava o registro como revisado e pendente de sincronizacao

#### Scenario: Tentativa de conclusao sem insumo
- **WHEN** o usuario tenta salvar a pulverizacao sem informar nenhum insumo
- **THEN** o sistema impede a conclusao e sinaliza a obrigatoriedade de ao menos um insumo conforme o contrato da operacao

### Requirement: Persistir multiplas pulverizacoes offline em SQLite

O aplicativo SHALL armazenar no SQLite local todas as pulverizacoes realizadas com seus metadados, rota GeoJSON, pontos de rastreamento, insumos associados e plantas confirmadas. O aplicativo SHALL permitir finalizar multiplas pulverizacoes sem conexao, mantendo todas visiveis no historico com estado pendente.

#### Scenario: Criar multiplas pulverizacoes offline
- **WHEN** o operador finaliza duas ou mais pulverizacoes sucessivas sem acesso a internet
- **THEN** todas as pulverizacoes permanecem persistidas no SQLite com seus dados completos e disponiveis no modal de pulverizacoes salvas

### Requirement: Listar e sincronizar pulverizacoes salvas via RPC

O aplicativo SHALL disponibilizar no quarto botao da barra de acoes o modal de Pulverizacoes Salvas, exibindo a lista de todas as pulverizacoes locais com data, zona, total de plantas, total de insumos e status (`draft`, `reviewed`, `synced`, `error`). O sistema SHALL disponibilizar botao de Sincronizar apenas para pulverizacoes revisadas, executando a chamada a RPC remota `sync_reviewed_spraying_operation(p_payload jsonb)`.

#### Scenario: Sincronizar pulverizacao revisada com sucesso
- **WHEN** o usuario clica em Sincronizar em uma pulverizacao revisada com conexao disponivel
- **THEN** o sistema envia o payload estruturado contendo `localOperationId`, `deviceId`, `operation`, `route`, `trackPoints`, `inputs` e `confirmedPlants` para a RPC `sync_reviewed_spraying_operation`
- **AND** apos o retorno com sucesso (`field_operation_id`, `route_id`, etc.), atualiza o status local para `synced` e preserva os identificadores remotos

#### Scenario: Falha ou ausencia de conexao na sincronizacao
- **WHEN** a sincronizacao falha por ausencia de internet ou erro de rede
- **THEN** a pulverizacao permanece intacta no SQLite com status `error` ou `reviewed`, permitindo nova tentativa manual posterior sem duplicacao de dados
