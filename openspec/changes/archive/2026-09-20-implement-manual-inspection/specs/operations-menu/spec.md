## MODIFIED Requirements

### Requirement: Abrir a tela de Inspeção
O aplicativo SHALL abrir uma tela própria e identificável de Inspeção quando o usuário selecionar o único card habilitado. A tela SHALL apresentar o mapa e as ações de inspeção dentro da navegação principal, preservando o destino Operações selecionado e as alterações salvas localmente.

#### Scenario: Selecionar Inspeção
- **WHEN** o usuário toca no card Inspeção
- **THEN** o sistema abre uma nova tela com o título Inspeção, mapa, card de ações e oferece a ação padrão de retorno para Operações
- **AND** a navegação inferior permanece visível com Operações selecionado

#### Scenario: Retornar da Inspeção
- **WHEN** o usuário aciona o retorno na tela Inspeção
- **THEN** o sistema volta à tela Operações preservando o destino Operações como selecionado
- **AND** as alterações já salvas no SQLite permanecem disponíveis para retomada
