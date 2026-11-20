## Purpose

Permitir ao operador registrar marcações rápidas de Previsão de Safra (`N`, `P`, `M`, `G`, `GG`) enquanto se desloca pelo pomar com visualização das plantas, marcador direcional de posição, rota percorrida, zoom livre sem reposicionamento forçado e gestão das marcações salvas localmente.

## ADDED Requirements

### Requirement: Exibir a tela de Previsão de Safra com mapa, botões de classificação e card de ações

A tela de Previsão de Safra SHALL apresentar estrutura semelhante à tela inicial de MIPD, com o mapa ocupando a área principal, uma linha com 5 botões circulares de classificação (`N`, `P`, `M`, `G`, `GG`) abaixo do mapa e, logo abaixo dessa linha, o card inferior contendo os botões **Carregar plantas** e **Marcações salvas**.

#### Scenario: Abrir a tela de Previsão de Safra
- **WHEN** o usuário abre a operação Previsão de Safra
- **THEN** o sistema exibe o mapa na área superior, a linha com os 5 botões circulares (`N`, `P`, `M`, `G`, `GG`) entre o mapa e o card inferior, e o card com os botões **Carregar plantas** e **Marcações salvas**

#### Scenario: Acionar Carregar plantas
- **WHEN** o usuário toca no botão **Carregar plantas**
- **THEN** o sistema atualiza os dados das plantas do pomar e plota seus marcadores no mapa

### Requirement: Exibir posição do usuário com direção, rota marcada e plantas no mapa

O mapa de Previsão de Safra SHALL exibir as plantas do pomar, o marcador da posição atual do usuário com orientação direcional (quando houver curso/direção de deslocamento) e a polilinha representando a rota percorrida durante a sessão na tela, seguindo o padrão visual da Pulverização.

#### Scenario: Deslocamento do usuário na tela de Previsão de Safra
- **WHEN** o serviço de localização emite novas posições válidas enquanto a tela está ativa
- **THEN** o sistema atualiza o marcador do usuário com sua direção de movimento e desenha no mapa a rota marcada pelos pontos percorridos, mantendo as plantas visíveis

### Requirement: Acompanhar a posição do usuário e suspender reposicionamento automático ao interagir ou dar zoom

O mapa SHALL atualizar e acompanhar a posição do usuário inicialmente, mas SHALL suspender o reposicionamento automático da câmera assim que o usuário interagir manualmente com o mapa (como dar zoom ou arrastar), permitindo visualizar uma área grande do pomar sem ser reposicionado automaticamente, exatamente como em **Operações -> Rotina do pomar -> Ocorrências**.

#### Scenario: Dar zoom ou mover o mapa manualmente
- **WHEN** o usuário realiza um gesto de zoom ou arraste no mapa para visualizar uma área grande
- **THEN** o sistema suspende o acompanhamento automático de câmera e mantém a área escolhida pelo usuário mesmo quando novas atualizações de GPS chegam
- **AND** o marcador do usuário e a rota continuam sendo atualizados normalmente no mapa

#### Scenario: Retomar centralização na posição do usuário
- **WHEN** o usuário aciona o botão de minha localização na barra superior
- **THEN** o sistema recentraliza a câmera na posição atual do usuário e retoma o acompanhamento

### Requirement: Registrar previsão de safra ao tocar nos botões circulares N, P, M, G ou GG e exibir marcador característico no mapa

Entre o mapa e o card de botões inferiores, o sistema SHALL apresentar 5 botões circulares dispostos na mesma linha com os labels `N` (Nenhuma), `P` (Pequena), `M` (Média), `G` (Grande) e `GG` (Muito Grande). Ao tocar em qualquer um desses botões, o sistema SHALL exibir um efeito visual/tátil forte de clique, gerar um registro local com a `latitude` e `longitude` da posição onde aconteceu o clique, a `classification` (`N`, `P`, `M`, `G` ou `GG`) e a data/hora em que o registro aconteceu, e plotar no mapa um marcador característico indicando o ponto marcado. Ao clicar no marcador do ponto marcado no mapa, o sistema SHALL abrir um modal compacto de baixo para cima detalhando o ponto marcado.

#### Scenario: Clicar em um botão circular de classificação com localização disponível
- **WHEN** o usuário clica em um dos botões circulares (`N`, `P`, `M`, `G` ou `GG`) com posição GPS disponível
- **THEN** o botão exibe efeito forte de clique e o sistema cria imediatamente um registro na tabela local contendo `latitude`, `longitude`, `classification` correspondente ao botão clicado e a data/hora do clique
- **AND** um marcador característico da classificação é exibido no mapa na posição registrada e o registro aparece no topo da lista de **Marcações salvas** (da mais nova para a mais antiga)

#### Scenario: Clicar no marcador de um ponto marcado no mapa
- **WHEN** o usuário toca no marcador característico de um ponto marcado no mapa
- **THEN** o sistema abre um modal compacto na parte inferior da tela detalhando o ponto marcado (classificação, data/hora, coordenadas e status) com opções rápidas para alterar a classificação, sincronizar ou excluir o ponto

#### Scenario: Clicar em um botão circular sem localização disponível
- **WHEN** o usuário clica em um dos botões circulares (`N`, `P`, `M`, `G` ou `GG`) e a localização atual do dispositivo não está disponível
- **THEN** o sistema informa ao usuário que a posição atual ainda não está disponível e não grava um registro sem coordenadas

### Requirement: Listar, editar classificação e excluir registros em Marcações Salvas

Ao clicar no botão **Marcações salvas**, o sistema SHALL exibir um modal com a lista de registros locais ordenada da marcação mais nova para a mais antiga (novas marcações no topo). Para cada item da lista, o usuário SHALL poder alterar a classificação (`N`, `P`, `M`, `G` ou `GG`) ou excluir o registro local.

#### Scenario: Abrir Marcações Salvas com registros locais
- **WHEN** o usuário toca em **Marcações salvas**
- **THEN** o sistema exibe os registros ordenados do mais recente no topo ao mais antigo na base, mostrando classificação, coordenadas, data/hora e status de sincronização

#### Scenario: Alterar a classificação de um registro salvo
- **WHEN** o usuário altera a classificação de um registro na lista de **Marcações salvas** para outro valor entre `N`, `P`, `M`, `G` ou `GG`
- **THEN** o sistema atualiza o valor de `classification` do registro no armazenamento local e marca o item como pendente de sincronização caso já estivesse sincronizado ou com erro

#### Scenario: Excluir um registro salvo localmente
- **WHEN** o usuário aciona a exclusão de um registro na lista de **Marcações salvas**
- **THEN** o sistema remove o registro da tabela local e atualiza imediatamente a lista exibida
