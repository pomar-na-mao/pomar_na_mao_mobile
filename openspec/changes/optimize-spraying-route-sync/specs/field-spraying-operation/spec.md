## Purpose

Definir a Pulverização de pomar como uma operação offline-first cuja rota consolidada é a fonte autoritativa para identificar espacialmente as plantas afetadas, sem materializar confirmações individuais no servidor.

## ADDED Requirements

### Requirement: Calcular e exibir plantas afetadas antes da sincronização

Durante a gravação da rota, o aplicativo SHALL manter as plantas disponíveis visíveis no mapa. Ao finalizar uma rota válida, SHALL calcular as plantas elegíveis localizadas a até 9 metros da rota, usando a consulta remota quando disponível ou o cálculo local quando offline, e SHALL destacar o resultado no mapa antes de permitir o salvamento para sincronização.

#### Scenario: Visualização das plantas durante a gravação
- **WHEN** o operador inicia a pulverização e a sessão entra no estado de gravação da rota
- **THEN** o aplicativo carrega as plantas em paralelo, sem bloquear o GPS, e mantém seus marcadores visíveis no mapa enquanto novos pontos da rota são registrados

#### Scenario: Visualização online das plantas afetadas
- **WHEN** o operador finaliza uma rota com conectividade e existem plantas elegíveis a até 9 metros
- **THEN** o aplicativo consulta o cálculo espacial remoto e destaca todas as plantas retornadas antes de abrir ou concluir o preenchimento da pulverização

#### Scenario: Visualização offline das plantas afetadas
- **WHEN** o operador finaliza uma rota sem conectividade
- **THEN** o aplicativo calcula as plantas afetadas sobre o cache local e exibe o resultado sem impedir que a pulverização seja salva localmente

#### Scenario: Rota sem plantas afetadas
- **WHEN** nenhuma planta elegível estiver dentro do raio da rota
- **THEN** o aplicativo exibe contagem zero e permite o preenchimento e salvamento da pulverização sem exigir confirmações individuais

### Requirement: Restringir a revisão ao preenchimento dos dados da pulverização

O modo de revisão SHALL manter a rota e as plantas calculadas visíveis apenas como informação e SHALL permitir somente o preenchimento ou ajuste dos dados operacionais exigidos para sincronização. O aplicativo MUST NOT oferecer ações para marcar, desmarcar, adicionar ou confirmar plantas individualmente.

#### Scenario: Tocar em uma planta durante a revisão
- **WHEN** o operador toca em uma planta calculada ou não calculada no modo de revisão
- **THEN** o estado de plantas afetadas permanece inalterado e nenhuma associação manual é criada ou removida

#### Scenario: Salvar dados preenchidos
- **WHEN** o operador preenche os campos obrigatórios e confirma o formulário
- **THEN** o aplicativo salva a operação local como pronta para sincronização sem persistir uma lista de plantas confirmadas

### Requirement: Preservar a operação offline e a rota consolidada

O aplicativo SHALL continuar capturando pontos GPS localmente durante a execução e SHALL consolidá-los em uma rota GeoJSON válida com pelo menos dois pontos distintos. Os pontos brutos podem permanecer locais enquanto necessários para gravação, retomada e cálculo prévio, mas MUST NOT integrar o contrato de sincronização remota.

#### Scenario: Gravar uma pulverização sem conexão
- **WHEN** uma sessão é iniciada, pausada, retomada e finalizada offline
- **THEN** o aplicativo preserva os pontos necessários localmente, produz a rota consolidada e mantém a operação disponível para sincronização posterior

#### Scenario: Tentar sincronizar rota inválida
- **WHEN** a operação não possui uma rota válida com pelo menos dois pontos distintos
- **THEN** o aplicativo impede a sincronização e preserva o registro local para correção ou descarte

### Requirement: Sincronizar somente a operação e sua rota autoritativa

O sistema SHALL sincronizar uma pulverização revisada por uma chamada idempotente contendo o identificador local, dispositivo, metadados operacionais, referências de máquina e calda e a rota consolidada. O payload MUST NOT conter pontos GPS brutos nem plantas confirmadas, e o servidor SHALL persistir somente o registro da operação e da rota necessários para representar a pulverização.

#### Scenario: Sincronização bem-sucedida
- **WHEN** uma pulverização revisada com rota válida é sincronizada
- **THEN** o servidor grava ou atualiza atomicamente a operação e uma rota consolidada e retorna seus identificadores e o instante de sincronização
- **AND** não cria registros em `field_operation_track_points`, `operation_inputs`, `plant_operation_history`, `plant_occurrences` ou `plant_occurrence_events`

#### Scenario: Repetir o mesmo envio
- **WHEN** o mesmo par de dispositivo e identificador local é sincronizado novamente
- **THEN** o servidor atualiza a operação e substitui sua rota de forma atômica sem duplicar registros

#### Scenario: Cliente envia campos removidos
- **WHEN** o payload inclui `trackPoints` ou `confirmedPlants`
- **THEN** a RPC rejeita o contrato obsoleto com erro de validação claro e sem gravar dados parciais

### Requirement: Consultar plantas da pulverização sob demanda

O sistema SHALL disponibilizar uma RPC autenticada que receba o identificador da operação de pulverização e um raio opcional, com padrão de 9 metros e limite máximo de 100 metros, e retorne `id`, `latitude` e `longitude` das plantas cuja localização esteja dentro do raio da rota consolidada.

#### Scenario: Consultar plantas alcançadas pela rota
- **WHEN** um usuário autorizado consulta uma pulverização existente com o raio padrão
- **THEN** a RPC retorna cada planta elegível alcançada por `ST_DWithin` uma única vez, em ordem determinística

#### Scenario: Excluir plantas inelegíveis
- **WHEN** uma planta dentro do raio está morta, inexistente ou inativa
- **THEN** a planta não integra o resultado

#### Scenario: Consultar operação incompatível
- **WHEN** o identificador não existe, não pertence a uma pulverização acessível ou não possui rota
- **THEN** a RPC retorna erro controlado ou resultado vazio conforme o contrato documentado, sem revelar dados de outro tenant

#### Scenario: Informar raio fora do limite
- **WHEN** o raio informado é menor ou igual a zero ou maior que 100 metros
- **THEN** a RPC rejeita a chamada sem executar a consulta espacial

### Requirement: Derivar resumos de pulverização a partir da rota

As consultas de pulverizações SHALL calcular sob demanda a quantidade de plantas afetadas e as zonas relacionadas usando a rota consolidada e as plantas elegíveis atuais, sem depender de associações materializadas em `plant_operation_history`.

#### Scenario: Listar pulverizações realizadas
- **WHEN** um consumidor solicita pulverizações com seus resumos espaciais
- **THEN** cada item retorna a contagem e as zonas derivadas da rota usando a mesma regra espacial e o mesmo raio padrão da consulta de pontos

#### Scenario: Alterar elegibilidade de uma planta após sincronização
- **WHEN** uma planta previamente dentro da rota passa a estar morta, inexistente ou inativa
- **THEN** consultas futuras deixam de incluí-la porque o resumo representa o estado atual calculado, e não um snapshot histórico

### Requirement: Preservar estruturas compartilhadas e remover somente dados exclusivos

A evolução do banco MUST manter tabelas compartilhadas por Inspeção e outros fluxos, incluindo `plant_operation_history` e `plant_occurrence_events`, e SHALL remover somente dados legados de pulverização e estruturas comprovadamente exclusivas que deixarem de ter consumidores.

#### Scenario: Aplicar a migration em banco com histórico misto
- **WHEN** existem registros de pulverização e inspeção nas tabelas compartilhadas
- **THEN** a migration remove apenas associações legadas pertencentes a pulverizações e preserva integralmente os registros dos demais tipos de operação

#### Scenario: Remover tabela exclusiva de pontos remotos
- **WHEN** a auditoria confirma que `field_operation_track_points` e suas dependências remanescentes são exclusivas da pulverização
- **THEN** a migration remove a referência dependente de `plant_operation_history` e elimina a tabela e seus índices em ordem segura
