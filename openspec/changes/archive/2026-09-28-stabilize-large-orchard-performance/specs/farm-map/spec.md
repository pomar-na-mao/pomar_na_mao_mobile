## ADDED Requirements

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
