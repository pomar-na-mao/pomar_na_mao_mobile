## Why

Durante inspeções em campo, o acompanhamento automático da localização reposiciona a câmera depois que o usuário desloca o mapa, impedindo consultar e marcar plantas distantes. Além disso, o nome atual não corresponde à terminologia desejada e o marcador de localização não comunica a direção de deslocamento do usuário.

## What Changes

- Renomear apenas o primeiro card de `Rotina do pomar`, de `Inspeção` para `Ocorrências`, preservando sua descrição, posição e destino.
- Alterar o título do topo da tela aberta por esse card, de `Inspeção` para `Ocorrências`, sem renomear a seção principal nem identificadores internos.
- Suspender o acompanhamento automático da câmera assim que o usuário deslocar, aplicar zoom, inclinar ou girar o mapa, mantendo o enquadramento manual apesar de novas amostras de localização.
- Manter a atualização do marcador do usuário enquanto a câmera estiver livre e oferecer o botão `Minha localização` como ação explícita para recentralizar e reativar o acompanhamento.
- Substituir o indicador circular por um marcador direcional que aponte o rumo válido recebido da localização, usando o curso derivado do deslocamento como fallback e omitindo orientação quando não houver dado confiável.

## Capabilities

### New Capabilities

Nenhuma.

### Modified Capabilities

- `operations-menu`: alterar o rótulo do primeiro card da Rotina do pomar e o título visível da tela correspondente para `Ocorrências`.
- `manual-inspection`: preservar a exploração manual do mapa diante de atualizações de localização e representar o rumo do usuário no marcador.

## Impact

- Apresentação do catálogo de operações e barra superior da tela atualmente implementada por `InspectionView`.
- Estado de acompanhamento, eventos de gesto e controles da câmera do mapa de inspeção.
- Criação e rotação do marcador de localização, aproveitando `UserLocation.heading` e o rastreamento de curso existente.
- Testes de widget e testes unitários relacionados ao catálogo, à câmera e à direção. Não há alteração de banco de dados, sincronização ou API remota.
