## MODIFIED Requirements

### Requirement: Iniciar com mapa e localização

O aplicativo SHALL renderizar o mapa ao abrir a rotina de inspeção, solicitar acesso à localização quando necessário e marcar a posição real do usuário quando disponível. Plantas SHALL ser carregadas somente pela ação explícita ou pela retomada de uma inspeção local. Depois de qualquer gesto manual de deslocamento, zoom, inclinação ou rotação, o aplicativo SHALL manter o enquadramento escolhido e suspender o acompanhamento automático da câmera até uma ação explícita de recentralização, sem interromper a atualização do marcador do usuário.

#### Scenario: Abrir com GPS disponível

- **WHEN** o usuário abre a rotina e a localização está disponível
- **THEN** o mapa é centralizado inicialmente no usuário, sua posição é indicada e a tela permite zoom, deslocamento, inclinação e rotação

#### Scenario: Explorar plantas distantes

- **WHEN** o usuário manipula o mapa para enquadrar uma área distante e chegam novas amostras de localização
- **THEN** a câmera permanece no enquadramento escolhido manualmente
- **AND** o marcador de posição continua sendo atualizado sem trazer a câmera de volta ao usuário

#### Scenario: Reativar o acompanhamento

- **WHEN** o usuário toca em `Minha localização` depois de explorar o mapa manualmente
- **THEN** o mapa recentraliza na posição atual e reativa o acompanhamento automático
- **AND** um novo gesto manual volta a suspender o acompanhamento

#### Scenario: Localização indisponível

- **WHEN** a permissão é negada, o GPS está desligado ou ocorre falha na localização
- **THEN** a tela informa a indisponibilidade e oferece nova tentativa, mantendo mapa e ações utilizáveis sem inventar uma posição

## ADDED Requirements

### Requirement: Indicar o rumo do usuário no mapa

Quando houver rumo confiável, o aplicativo SHALL representar a posição do usuário com um marcador em forma de seta orientado para esse rumo. O rumo SHALL priorizar o valor válido fornecido pela localização e SHALL poder usar o curso calculado entre posições válidas como fallback. O marcador SHALL continuar indicando a posição sem afirmar uma direção quando nenhum rumo confiável estiver disponível.

#### Scenario: Receber rumo válido

- **WHEN** uma atualização de localização contém um rumo válido entre 0 e 360 graus
- **THEN** a seta do marcador aponta para o rumo informado e acompanha atualizações posteriores

#### Scenario: Derivar o curso pelo deslocamento

- **WHEN** o rumo direto está indisponível e posições válidas demonstram deslocamento suficiente para calcular um curso confiável
- **THEN** a seta do marcador aponta para o curso calculado

#### Scenario: Não dispor de rumo confiável

- **WHEN** não existe rumo válido nem deslocamento suficiente para calcular o curso
- **THEN** o sistema mostra a posição do usuário com estado visual neutro, sem apresentar uma direção potencialmente incorreta

#### Scenario: Girar ou deslocar a câmera manualmente

- **WHEN** o usuário altera manualmente a orientação ou o enquadramento do mapa
- **THEN** o marcador continua apontando para o rumo geográfico correto sem recentralizar ou girar a câmera automaticamente
