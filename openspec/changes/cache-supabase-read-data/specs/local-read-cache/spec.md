## Purpose

Reduzir leituras HTTP repetidas do Supabase por meio de dados locais persistentes e compartilhados, com uma política explícita e segura para inicialização e atualização.

## ADDED Requirements

### Requirement: Compartilhar dados persistidos por projeto
O aplicativo SHALL manter um cache persistente isolado pela URL do projeto Supabase para `plants`, `farm`, `zones`, `regions` e `occurrence_types`. Fazenda, Inventário e Inspeção SHALL consumir o mesmo estado local aplicável a cada conjunto, inclusive após navegação ou reinício do aplicativo.

#### Scenario: Reutilizar dados entre telas
- **WHEN** uma tela conclui a obtenção e persistência de um conjunto e outra tela solicita o mesmo conjunto
- **THEN** a segunda tela recebe os dados locais já persistidos sem iniciar uma nova consulta HTTP ao Supabase

#### Scenario: Reabrir o aplicativo com cache
- **WHEN** o aplicativo é reiniciado e existe cache íntegro para o projeto configurado
- **THEN** os dados permanecem disponíveis sem depender de uma nova consulta remota

#### Scenario: Trocar o projeto configurado
- **WHEN** o aplicativo é executado com uma URL de projeto Supabase diferente
- **THEN** nenhum dado persistido para o projeto anterior é apresentado como pertencente ao projeto atual

### Requirement: Inicializar dados de referência somente quando ausentes
O aplicativo SHALL obter remotamente `farm`, `zones`, cada conjunto de `regions` solicitado e `occurrence_types` somente quando o respectivo conjunto ainda não possuir um cache local utilizável. Após uma obtenção bem-sucedida, solicitações posteriores SHALL usar o cache sem atualização automática.

#### Scenario: Primeira solicitação de um conjunto
- **WHEN** um conjunto de referência é solicitado e ainda não existe cache local utilizável para ele
- **THEN** o aplicativo consulta o Supabase, persiste o resultado completo e o disponibiliza ao consumidor

#### Scenario: Solicitação repetida de um conjunto
- **WHEN** um conjunto de referência já persistido é solicitado novamente durante a mesma sessão ou após reinício
- **THEN** o aplicativo retorna o conteúdo local e não envia uma nova consulta HTTP para esse conjunto

#### Scenario: Falha antes do primeiro cache
- **WHEN** a consulta inicial de um conjunto falha e não existe versão local utilizável
- **THEN** o consumidor recebe um estado de erro recuperável e uma tentativa posterior pode repetir a inicialização

### Requirement: Consolidar solicitações remotas concorrentes
O aplicativo SHALL compartilhar uma única operação remota em andamento entre solicitações simultâneas do mesmo conjunto e do mesmo projeto. Uma carga paginada de plantas ou ocorrências SHALL ser considerada uma operação lógica única, ainda que necessite de múltiplas páginas HTTP.

#### Scenario: Duas telas solicitam o mesmo dado ausente
- **WHEN** dois consumidores solicitam simultaneamente um conjunto que ainda não está em cache
- **THEN** somente uma operação remota é executada e ambos recebem o mesmo resultado persistido

#### Scenario: Operação compartilhada falha
- **WHEN** a operação remota compartilhada termina com erro
- **THEN** todos os solicitantes recebem a falha e uma solicitação posterior pode iniciar uma nova tentativa

### Requirement: Controlar a atualização remota de plantas
Na ausência de qualquer cache de plantas, o aplicativo SHALL permitir uma inicialização remota paginada e persistir o resultado completo. Depois que esse cache existir, o aplicativo SHALL atualizar remotamente `plants` somente pela ação Carregar plantas da Inspeção; abrir, reabrir ou tentar novamente em Fazenda ou Inventário SHALL NOT atualizar a tabela remotamente.

#### Scenario: Inicializar plantas sem cache
- **WHEN** um consumidor precisa de plantas e ainda não existe uma versão local, nem mesmo uma versão vazia confirmada
- **THEN** o aplicativo executa uma única carga remota paginada, persiste o conjunto completo e atende os consumidores concorrentes a partir desse resultado

#### Scenario: Consumir plantas já armazenadas
- **WHEN** Fazenda, Inventário ou Inspeção solicita plantas após o cache ter sido inicializado
- **THEN** o aplicativo usa o conjunto local sem enviar GET para `plants`

#### Scenario: Atualizar pelo botão da Inspeção
- **WHEN** o usuário aciona Carregar plantas na tela de Inspeção
- **THEN** o aplicativo consulta novamente todas as páginas de `plants` e o estado de ocorrências abertas necessário à inspeção, publica uma nova versão local compartilhada e não exige consultas adicionais das outras telas

### Requirement: Publicar atualizações completas e preservar trabalho local
Uma inicialização ou atualização SHALL substituir a versão compartilhada somente depois de obter e validar todos os dados remotos necessários. Falhas SHALL preservar a última versão íntegra, e alterações de inspeção ainda não sincronizadas SHALL continuar sobrepostas ao estado remoto atualizado.

#### Scenario: Falhar durante uma atualização
- **WHEN** qualquer página de plantas ou a consulta de ocorrências abertas falha durante Carregar plantas e existe uma versão local anterior
- **THEN** o aplicativo mantém a versão anterior disponível, informa que a atualização falhou e não publica um conjunto parcial

#### Scenario: Atualizar com alterações pendentes
- **WHEN** uma atualização remota é concluída enquanto existem mudanças locais de inspeção ainda não sincronizadas
- **THEN** o novo estado remoto é persistido e as mudanças locais pendentes continuam refletidas nas plantas correspondentes

#### Scenario: Propagar a nova versão aos consumidores
- **WHEN** Carregar plantas conclui com sucesso
- **THEN** Fazenda, Inventário e Inspeção passam a usar a nova versão compartilhada sem executar consultas remotas próprias

### Requirement: Derivar visões de plantas do mesmo conjunto
O aplicativo SHALL derivar do conjunto local completo as plantas exibidas na Fazenda, as plantas elegíveis da Inspeção e os totais do Inventário. A Inspeção SHALL incluir apenas registros com `non_existent = false`, e o Inventário SHALL calcular separadamente os totais de `non_existent = false` e `non_existent = true` sem consultas remotas de contagem.

#### Scenario: Consumidores usam critérios diferentes
- **WHEN** o cache contém plantas existentes e posições marcadas como não existentes
- **THEN** Fazenda recebe o conjunto aplicável ao mapa, Inspeção recebe somente plantas existentes e Inventário apresenta os dois totais derivados da mesma versão

#### Scenario: Cache confirmado como vazio
- **WHEN** uma carga remota completa retorna zero plantas e essa versão vazia é persistida
- **THEN** solicitações posteriores tratam o conjunto como vazio conhecido e não repetem automaticamente a consulta remota
