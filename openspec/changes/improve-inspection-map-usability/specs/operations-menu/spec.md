## ADDED Requirements

### Requirement: Nomear a rotina geral como Ocorrências

O aplicativo SHALL exibir o primeiro card do módulo `Rotina do pomar` com o rótulo `Ocorrências` e SHALL exibir `Ocorrências` como título no topo da tela aberta por esse card. A mudança de rótulo SHALL NOT alterar o destino do card, sua posição no módulo, sua descrição nem o nome do destino `Operações` na navegação principal.

#### Scenario: Visualizar o primeiro card da Rotina do pomar

- **WHEN** o usuário abre o catálogo de operações
- **THEN** o primeiro card de `Rotina do pomar` apresenta o nome `Ocorrências`
- **AND** os demais cards e os títulos dos módulos mantêm seus nomes

#### Scenario: Abrir a rotina pelo card renomeado

- **WHEN** o usuário toca no primeiro card `Ocorrências`
- **THEN** o sistema abre a mesma rotina de mapa e registro anteriormente identificada como Inspeção
- **AND** o topo da tela apresenta `Ocorrências` ao lado da ação de voltar

#### Scenario: Retornar da rotina renomeada

- **WHEN** o usuário aciona o retorno na tela `Ocorrências`
- **THEN** o sistema volta ao catálogo preservando o destino principal `Operações` selecionado e os dados salvos
