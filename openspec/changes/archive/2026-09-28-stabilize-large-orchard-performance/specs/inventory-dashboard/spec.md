## MODIFIED Requirements

### Requirement: Contabilizar as plantas por disponibilidade

O aplicativo SHALL exibir os totais exatos da revisao completa do cache compartilhado para `non_existent = false` como "Plantas existentes" e `non_existent = true` como "Disponiveis para plantio". Na ausencia de cache SHALL usar a inicializacao compartilhada prevista em `local-read-cache`; reabrir ou tentar novamente SHALL NOT consultar contagens remotas proprias. Totais SHALL ser derivados ou persistidos por revisao sem exigir hidratacao integral das plantas a cada abertura do Inventario.

#### Scenario: Existem plantas nas duas categorias
- **WHEN** a revisao local contem registros com `non_existent = false` e com `non_existent = true`
- **THEN** o sistema apresenta em indicadores distintos o total exato de cada categoria da mesma revisao

#### Scenario: Uma categoria nao possui registros
- **WHEN** uma categoria possui zero registros na revisao completa
- **THEN** o indicador apresenta zero sem tratar o resultado como erro

#### Scenario: Os dados mudam antes de uma nova carga
- **WHEN** apenas a fonte remota muda e o usuario reabre ou tenta novamente no Inventario
- **THEN** o sistema continua exibindo a revisao local ate a atualizacao explicita de plantas na Inspecao

#### Scenario: Publicar nova revisao
- **WHEN** a atualizacao explicita publica um novo cache completo
- **THEN** os indicadores passam a representar essa revisao sem consultas remotas adicionais

#### Scenario: Cache ainda ausente
- **WHEN** o Inventario abre sem uma revisao local completa
- **THEN** os indicadores mostram carregamento local ao bloco e participam da inicializacao compartilhada sem impedir a navegacao
