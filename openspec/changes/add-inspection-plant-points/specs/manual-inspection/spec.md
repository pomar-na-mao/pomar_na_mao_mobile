## ADDED Requirements

### Requirement: Marcar pontos de plantas no mapa
A tela de Inspecao SHALL permitir que o usuario toque e segure em um ponto livre do mapa para iniciar a adicao local de uma planta, capturando latitude e longitude do ponto acionado. O toque simples em ponto livre, marcador de planta existente, agrupamento, controle do mapa ou elemento de interface SHALL preservar o comportamento atual e SHALL NOT criar uma nova marcacao.

#### Scenario: Tocar e segurar em ponto livre
- **WHEN** o usuario toca e segura em uma area livre do mapa de Inspecao
- **THEN** o aplicativo captura a latitude e longitude do ponto acionado
- **AND** abre um modal para confirmar a planta adicionada

#### Scenario: Tocar em planta existente
- **WHEN** o usuario toca em um marcador de planta existente
- **THEN** o aplicativo abre o editor da planta existente
- **AND** nenhuma planta adicionada localmente e criada

### Requirement: Confirmar planta adicionada com estado de inexistencia e zona
Ao iniciar uma planta adicionada pelo mapa, o aplicativo SHALL abrir um modal que apresenta as coordenadas capturadas, selecao opcional de zona (iniciando com a zona ativa no filtro, quando houver) e um controle claro para definir se a planta sera sincronizada como `non_existent = true` ou `non_existent = false`. Confirmar o modal SHALL salvar a planta adicionada localmente com suas coordenadas, valor de inexistencia e `zone_id` selecionado; cancelar SHALL descartar a marcacao sem alterar inspecoes, ocorrencias ou plantas existentes.

#### Scenario: Confirmar como existente com zona
- **WHEN** o usuario toca e segura no mapa, mantem ou seleciona uma zona, deixa a opcao de planta inexistente desativada e confirma
- **THEN** a lista local de plantas adicionadas recebe um item com latitude, longitude, `zoneId` e `non_existent = false`
- **AND** a marcacao fica visivel no mapa como item pendente de sincronizacao

#### Scenario: Confirmar como inexistente sem zona
- **WHEN** o usuario toca e segura no mapa, seleciona 'Sem zona', ativa a opcao de planta inexistente e confirma
- **THEN** a lista local de plantas adicionadas recebe um item com latitude, longitude, `zoneId = null` e `non_existent = true`
- **AND** a marcacao fica distinguivel de plantas existentes ja cadastradas

#### Scenario: Cancelar confirmacao
- **WHEN** o usuario fecha ou cancela o modal de confirmacao
- **THEN** nenhuma planta adicionada localmente e salva
- **AND** a fila de inspecoes permanece inalterada

### Requirement: Listar plantas adicionadas separadamente
A tela de Inspecao SHALL oferecer um botao proprio para abrir a lista de plantas adicionadas localmente. Essa lista SHALL ser separada de Inspecoes salvas, SHALL apresentar status de sincronizacao por item, exibir a zona associada quando informada e SHALL permitir revisar os pontos pendentes, com erro e sincronizados sem misturar registros de inspecao.

#### Scenario: Abrir lista de plantas adicionadas
- **WHEN** o usuario aciona o botao de plantas adicionadas
- **THEN** o aplicativo abre uma lista contendo somente plantas adicionadas pelo toque longo no mapa
- **AND** a lista de Inspecoes salvas nao e exibida nesse fluxo

#### Scenario: Lista sem plantas adicionadas
- **WHEN** nao existem plantas adicionadas localmente
- **THEN** a lista informa que nenhuma planta foi adicionada
- **AND** o usuario pode fechar a lista sem alterar a inspecao em andamento

#### Scenario: Ver status de itens locais
- **WHEN** existem plantas adicionadas pendentes, com erro ou sincronizadas
- **THEN** cada item exibe sua coordenada, a zona quando informada, o valor de `non_existent` e seu status de sincronizacao

### Requirement: Remover planta adicionada por duplo toque
A tela de Inspecao SHALL permitir remover uma planta adicionada localmente com duplo toque na marcacao local do mapa ou no item da lista propria. A remocao SHALL apagar somente o registro local da fila de plantas adicionadas e SHALL NOT alterar inspecoes, ocorrencias ou plantas remotas ja sincronizadas.

#### Scenario: Remover marcacao local
- **GIVEN** existe uma planta adicionada localmente visivel no mapa e na lista propria
- **WHEN** o usuario executa duplo toque nessa marcacao ou no item correspondente
- **THEN** a planta adicionada e removida da lista propria
- **AND** a marcacao local deixa de aparecer no mapa
- **AND** a lista de inspecoes permanece inalterada
