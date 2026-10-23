## MODIFIED Requirements

### Requirement: Compartilhar dados persistidos por projeto

O aplicativo SHALL manter um cache persistente isolado pela URL do projeto Supabase para `plants`, `farm`, `zones`, `regions` e `occurrence_types`. Fazenda, Inventario, Inspecao e MIPD SHALL consumir o mesmo estado local aplicavel a cada conjunto, inclusive apos navegacao ou reinicio do aplicativo. O catalogo de `occurrence_types` SHALL preservar a categoria de cada item para permitir visoes filtradas sem duplicar o cache fisico.

#### Scenario: Reutilizar dados entre telas
- **WHEN** uma tela conclui a obtencao e persistencia de um conjunto e outra tela solicita o mesmo conjunto
- **THEN** a segunda tela recebe os dados locais ja persistidos sem iniciar uma nova consulta HTTP ao Supabase

#### Scenario: Reabrir o aplicativo com cache
- **WHEN** o aplicativo e reiniciado e existe cache integro para o projeto configurado
- **THEN** os dados permanecem disponiveis sem depender de uma nova consulta remota

#### Scenario: Trocar o projeto configurado
- **WHEN** o aplicativo e executado com uma URL de projeto Supabase diferente
- **THEN** nenhum dado persistido para o projeto anterior e apresentado como pertencente ao projeto atual

#### Scenario: Consumidores filtram o mesmo catalogo
- **WHEN** o cache contem tipos de ocorrencia de varias categorias
- **THEN** a Inspecao recebe todas as categorias exceto `PEST_DISEASE` e o MIPD recebe somente `PEST_DISEASE` a partir da mesma revisao local

### Requirement: Inicializar dados de referencia somente quando ausentes

O aplicativo SHALL obter remotamente `farm`, `zones`, cada conjunto de `regions` solicitado e o catalogo completo de `occurrence_types` somente quando o respectivo conjunto ainda nao possuir um cache local utilizavel. Apos uma obtencao bem-sucedida, solicitacoes posteriores SHALL usar o cache sem atualizacao automatica.

#### Scenario: Primeira solicitacao de um conjunto
- **WHEN** um conjunto de referencia e solicitado e ainda nao existe cache local utilizavel para ele
- **THEN** o aplicativo consulta o Supabase, persiste o resultado completo e o disponibiliza ao consumidor

#### Scenario: Inicializar o catalogo de ocorrencias
- **WHEN** Inspecao ou MIPD solicita tipos de ocorrencia e o catalogo ainda nao esta em cache
- **THEN** o aplicativo busca e persiste todos os tipos com suas categorias antes de aplicar o filtro do consumidor

#### Scenario: Solicitacao repetida de um conjunto
- **WHEN** um conjunto de referencia ja persistido e solicitado novamente durante a mesma sessao ou apos reinicio
- **THEN** o aplicativo retorna o conteudo local e nao envia uma nova consulta HTTP para esse conjunto

#### Scenario: Falha antes do primeiro cache
- **WHEN** a consulta inicial de um conjunto falha e nao existe versao local utilizavel
- **THEN** o consumidor recebe um estado de erro recuperavel e uma tentativa posterior pode repetir a inicializacao

### Requirement: Controlar a atualizacao remota de plantas

Na ausencia de qualquer cache de plantas, o aplicativo SHALL permitir uma inicializacao remota paginada e persistir o resultado completo. Depois que esse cache existir, o aplicativo SHALL atualizar remotamente os dados compartilhados somente pela acao Carregar Plantas da Inspecao ou do MIPD. Essa acao SHALL atualizar de forma coordenada `plants`, `farm`, `zones`, `regions`, o catalogo completo de `occurrence_types` e o estado de ocorrencias abertas necessario as operacoes; abrir, reabrir ou tentar novamente em Fazenda ou Inventario SHALL NOT atualizar esses conjuntos remotamente.

#### Scenario: Inicializar plantas sem cache
- **WHEN** um consumidor precisa de plantas e ainda nao existe uma versao local, nem mesmo uma versao vazia confirmada
- **THEN** o aplicativo executa uma unica carga remota paginada, persiste o conjunto completo e atende os consumidores concorrentes a partir desse resultado

#### Scenario: Consumir plantas ja armazenadas
- **WHEN** Fazenda, Inventario, Inspecao ou MIPD solicita plantas apos o cache ter sido inicializado
- **THEN** o aplicativo usa o conjunto local sem enviar GET para `plants`

#### Scenario: Atualizar pelo botao da Inspecao
- **WHEN** o usuario aciona Carregar Plantas na tela de Inspecao
- **THEN** o aplicativo atualiza todos os conjuntos compartilhados e o estado de ocorrencias abertas, publica uma nova versao local coordenada e nao exige consultas adicionais das outras telas

#### Scenario: Atualizar pelo botao do MIPD
- **WHEN** o usuario aciona Carregar Plantas na tela MIPD
- **THEN** o aplicativo executa a mesma rotina completa usada pela Inspecao e publica o resultado para todos os consumidores

### Requirement: Publicar atualizacoes completas e preservar trabalho local

Uma inicializacao ou atualizacao SHALL substituir a versao compartilhada somente depois de obter e validar todos os dados remotos necessarios. Falhas SHALL preservar a ultima versao integra, e alteracoes de Inspecao ou marcacoes MIPD ainda nao sincronizadas SHALL continuar disponiveis e sobrepostas ao estado remoto aplicavel.

#### Scenario: Falhar durante uma atualizacao
- **WHEN** qualquer pagina ou conjunto necessario falha durante Carregar Plantas e existe uma versao local anterior
- **THEN** o aplicativo mantem a versao anterior disponivel, informa que a atualizacao falhou e nao publica um conjunto parcial

#### Scenario: Atualizar com alteracoes pendentes
- **WHEN** uma atualizacao remota e concluida enquanto existem mudancas locais de Inspecao ou MIPD ainda nao sincronizadas
- **THEN** o novo estado remoto e persistido e os trabalhos locais pendentes continuam disponiveis para consulta e sincronizacao

#### Scenario: Propagar a nova versao aos consumidores
- **WHEN** Carregar Plantas conclui com sucesso na Inspecao ou no MIPD
- **THEN** Fazenda, Inventario, Inspecao e MIPD passam a usar a nova versao compartilhada sem executar consultas remotas proprias

