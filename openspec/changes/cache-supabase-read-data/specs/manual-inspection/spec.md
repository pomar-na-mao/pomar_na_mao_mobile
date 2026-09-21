## MODIFIED Requirements

### Requirement: Carregar plantas existentes
A ação Carregar plantas SHALL atualizar remotamente todas as páginas de `plants`, persistir o conjunto completo compartilhado e disponibilizar na Inspeção somente registros com `non_existent = false` e coordenadas válidas. O carregamento SHALL obter o estado de ocorrências abertas das plantas elegíveis para permitir edição correta offline e SHALL reutilizar `occurrence_types` localmente, consultando o catálogo remoto somente quando ele ainda não possuir cache utilizável. Dados incompletos SHALL NOT ser publicados como ausência de plantas ou ocorrências.

#### Scenario: Resultado maior que uma página
- **WHEN** a consulta retorna mais plantas que o limite de uma página
- **THEN** todas as páginas são carregadas e o conjunto completo é persistido
- **AND** todas as plantas elegíveis com coordenadas válidas ficam disponíveis no mapa da Inspeção e registros com `non_existent = true` não são exibidos nela

#### Scenario: Repetir o carregamento explícito
- **WHEN** o usuário aciona Carregar plantas e já existe uma versão local
- **THEN** o aplicativo solicita uma nova versão remota de plantas e ocorrências abertas, mantendo o catálogo local já disponível

#### Scenario: Consulta vazia ou falha sem cache
- **WHEN** a consulta completa termina vazia ou falha sem dados locais utilizáveis
- **THEN** a tela distingue Nenhuma planta encontrada de falha de carregamento, encerra o indicador de progresso e permite tentar novamente

#### Scenario: Trabalhar com dados já carregados
- **WHEN** o dispositivo está offline e existe um conjunto local completo de plantas, tipos e ocorrências
- **THEN** o aplicativo permite retomar esse conjunto, informa que os dados são locais e não inicia atualização automática ao abrir a tela
- **AND** não substitui alterações pendentes durante novas tentativas de carregamento

#### Scenario: Falhar durante a atualização manual
- **WHEN** Carregar plantas falha depois de existir uma versão local íntegra
- **THEN** o aplicativo mantém essa versão disponível, informa a falha da atualização e não substitui ocorrências por um estado parcial
