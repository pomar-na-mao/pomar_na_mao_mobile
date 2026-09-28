# local-read-cache Specification

## Purpose

Reduzir leituras HTTP repetidas do Supabase por meio de dados locais persistentes e compartilhados, com uma politica explicita e segura para inicializacao e atualizacao.

## Requirements

### Requirement: Compartilhar dados persistidos por projeto

O aplicativo SHALL manter um cache persistente isolado pela URL do projeto Supabase para `plants`, `farm`, `zones`, `regions` e `occurrence_types`. Fazenda, Inventario e Inspecao SHALL consumir o mesmo estado local aplicavel a cada conjunto, inclusive apos navegacao ou reinicio do aplicativo.

#### Scenario: Reutilizar dados entre telas
- **WHEN** uma tela conclui a obtencao e persistencia de um conjunto e outra tela solicita o mesmo conjunto
- **THEN** a segunda tela recebe os dados locais ja persistidos sem iniciar uma nova consulta HTTP ao Supabase

#### Scenario: Reabrir o aplicativo com cache
- **WHEN** o aplicativo e reiniciado e existe cache integro para o projeto configurado
- **THEN** os dados permanecem disponiveis sem depender de uma nova consulta remota

#### Scenario: Trocar o projeto configurado
- **WHEN** o aplicativo e executado com uma URL de projeto Supabase diferente
- **THEN** nenhum dado persistido para o projeto anterior e apresentado como pertencente ao projeto atual

### Requirement: Inicializar dados de referencia somente quando ausentes

O aplicativo SHALL obter remotamente `farm`, `zones`, cada conjunto de `regions` solicitado e `occurrence_types` somente quando o respectivo conjunto ainda nao possuir um cache local utilizavel. Apos uma obtencao bem-sucedida, solicitacoes posteriores SHALL usar o cache sem atualizacao automatica.

#### Scenario: Primeira solicitacao de um conjunto
- **WHEN** um conjunto de referencia e solicitado e ainda nao existe cache local utilizavel para ele
- **THEN** o aplicativo consulta o Supabase, persiste o resultado completo e o disponibiliza ao consumidor

#### Scenario: Solicitacao repetida de um conjunto
- **WHEN** um conjunto de referencia ja persistido e solicitado novamente durante a mesma sessao ou apos reinicio
- **THEN** o aplicativo retorna o conteudo local e nao envia uma nova consulta HTTP para esse conjunto

#### Scenario: Falha antes do primeiro cache
- **WHEN** a consulta inicial de um conjunto falha e nao existe versao local utilizavel
- **THEN** o consumidor recebe um estado de erro recuperavel e uma tentativa posterior pode repetir a inicializacao

### Requirement: Consolidar solicitacoes remotas concorrentes

O aplicativo SHALL compartilhar uma unica operacao remota em andamento entre solicitacoes simultaneas do mesmo conjunto e do mesmo projeto. Uma carga paginada de plantas ou ocorrencias SHALL ser considerada uma operacao logica unica, ainda que necessite de multiplas paginas HTTP.

#### Scenario: Duas telas solicitam o mesmo dado ausente
- **WHEN** dois consumidores solicitam simultaneamente um conjunto que ainda nao esta em cache
- **THEN** somente uma operacao remota e executada e ambos recebem o mesmo resultado persistido

#### Scenario: Operacao compartilhada falha
- **WHEN** a operacao remota compartilhada termina com erro
- **THEN** todos os solicitantes recebem a falha e uma solicitacao posterior pode iniciar uma nova tentativa

### Requirement: Controlar a atualizacao remota de plantas

Na ausencia de qualquer cache de plantas, o aplicativo SHALL permitir uma inicializacao remota paginada e persistir o resultado completo. Depois que esse cache existir, o aplicativo SHALL atualizar remotamente `plants` somente pela acao Carregar plantas da Inspecao; abrir, reabrir ou tentar novamente em Fazenda ou Inventario SHALL NOT atualizar a tabela remotamente.

#### Scenario: Inicializar plantas sem cache
- **WHEN** um consumidor precisa de plantas e ainda nao existe uma versao local, nem mesmo uma versao vazia confirmada
- **THEN** o aplicativo executa uma unica carga remota paginada, persiste o conjunto completo e atende os consumidores concorrentes a partir desse resultado

#### Scenario: Consumir plantas ja armazenadas
- **WHEN** Fazenda, Inventario ou Inspecao solicita plantas apos o cache ter sido inicializado
- **THEN** o aplicativo usa o conjunto local sem enviar GET para `plants`

#### Scenario: Atualizar pelo botao da Inspecao
- **WHEN** o usuario aciona Carregar plantas na tela de Inspecao
- **THEN** o aplicativo consulta novamente todas as paginas de `plants` e o estado de ocorrencias abertas necessario a inspecao, publica uma nova versao local compartilhada e nao exige consultas adicionais das outras telas

### Requirement: Publicar atualizacoes completas e preservar trabalho local

Uma inicializacao ou atualizacao SHALL substituir a versao compartilhada somente depois de obter e validar todos os dados remotos necessarios. Falhas SHALL preservar a ultima versao integra, e alteracoes de inspecao ainda nao sincronizadas SHALL continuar sobrepostas ao estado remoto atualizado.

#### Scenario: Falhar durante uma atualizacao
- **WHEN** qualquer pagina de plantas ou a consulta de ocorrencias abertas falha durante Carregar plantas e existe uma versao local anterior
- **THEN** o aplicativo mantem a versao anterior disponivel, informa que a atualizacao falhou e nao publica um conjunto parcial

#### Scenario: Atualizar com alteracoes pendentes
- **WHEN** uma atualizacao remota e concluida enquanto existem mudancas locais de inspecao ainda nao sincronizadas
- **THEN** o novo estado remoto e persistido e as mudancas locais pendentes continuam refletidas nas plantas correspondentes

#### Scenario: Propagar a nova versao aos consumidores
- **WHEN** Carregar plantas conclui com sucesso
- **THEN** Fazenda, Inventario e Inspecao passam a usar a nova versao compartilhada sem executar consultas remotas proprias

### Requirement: Derivar visoes de plantas do mesmo conjunto

O aplicativo SHALL derivar do conjunto local completo as plantas exibidas na Fazenda, as plantas elegiveis da Inspecao e os totais do Inventario. A Inspecao SHALL incluir apenas registros com `non_existent = false`, e o Inventario SHALL calcular separadamente os totais de `non_existent = false` e `non_existent = true` sem consultas remotas de contagem.

#### Scenario: Consumidores usam criterios diferentes
- **WHEN** o cache contem plantas existentes e posicoes marcadas como nao existentes
- **THEN** Fazenda recebe o conjunto aplicavel ao mapa, Inspecao recebe somente plantas existentes e Inventario apresenta os dois totais derivados da mesma versao

#### Scenario: Cache confirmado como vazio
- **WHEN** uma carga remota completa retorna zero plantas e essa versao vazia e persistida
- **THEN** solicitacoes posteriores tratam o conjunto como vazio conhecido e nao repetem automaticamente a consulta remota

### Requirement: Consumir grandes revisoes sem bloquear interacao

O cache SHALL atender consumidores concorrentes de uma mesma revisao com hidratacao compartilhada e SHALL cumprir os orcamentos de `runtime-stability`. Trocas de tela e eventos de GPS SHALL NOT provocar nova decodificacao integral de uma revisao ja hidratada. Revisoes antigas sem consumidores SHALL ser liberadas.

#### Scenario: Abrir Fazenda e Inspecao em sequencia
- **WHEN** ambas solicitam a mesma revisao completa de 21.000 plantas
- **THEN** a hidratacao integral e compartilhada e a navegacao continua respondendo durante sua preparacao

#### Scenario: Editar sem mudar a quantidade de plantas
- **WHEN** uma coordenada, ocorrencia ou estado local confirmado muda mantendo a quantidade de registros
- **THEN** a revisao observavel muda e os consumidores recebem a alteracao, inclusive filtros e marcadores

### Requirement: Preservar publicacao atomica com processamento limitado

Leituras e gravacoes em lotes SHALL manter a revisao anterior acessivel ate a publicacao completa da sucessora. Interrupcao, timeout, falta de espaco ou erro de validacao SHALL NOT publicar dados parciais nem remover a fila local. Uma edicao local confirmada durante a atualizacao SHALL estar sobreposta na revisao publicada.

#### Scenario: Interromper entre lotes
- **WHEN** o processo e encerrado depois de persistir parte de uma atualizacao
- **THEN** a reabertura utiliza a ultima revisao completa e recupera ou descarta apenas o staging incompleto

#### Scenario: Editar enquanto atualiza
- **WHEN** o usuario confirma uma ocorrencia enquanto uma nova carga remota esta sendo preparada
- **THEN** a publicacao preserva essa edicao e os identificadores de sincronizacao existentes

#### Scenario: Primeira carga falha
- **WHEN** nao existe cache e uma pagina falha
- **THEN** a ausencia de revisao completa e mantida, aparece erro recuperavel e a nova tentativa nao reutiliza a pagina incompleta como snapshot valido
