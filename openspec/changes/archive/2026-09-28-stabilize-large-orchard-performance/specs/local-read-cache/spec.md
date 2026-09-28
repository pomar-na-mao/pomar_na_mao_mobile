## ADDED Requirements

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
