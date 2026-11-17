## Context

Veja `proposal.md` para a motivação. O primeiro card de `Rotina do pomar` é definido em `operation_definition.dart` e abre `InspectionView`, cujo `AppBar` ainda usa o título `Inspeção`.

Na tela de inspeção, cada nova `UserLocation` chama o acompanhamento de `UserMapNavigator`. Além disso, `onCameraIdle` invalida o controle de posição e solicita novo acompanhamento; quando o usuário deixou sua posição fora da região visível, esse fluxo anima a câmera de volta. A tela já registra interação por ponteiro, preserva a última câmera e oferece `Minha localização`, mas esses sinais ainda não governam o acompanhamento.

O modelo `UserLocation` e o adaptador do `geolocator` já transportam `heading` e `speed`. `UserCourseTracker` também calcula curso por deslocamento quando o rumo direto não é confiável, porém o resultado hoje é usado pela câmera e não pelo marcador circular.

## Goals / Non-Goals

**Goals:**

- Tornar explícito e testável o estado `acompanhando` versus `exploração manual` da câmera.
- Cancelar com segurança uma decisão assíncrona de acompanhamento quando uma interação manual ocorrer durante a consulta da região visível.
- Reutilizar a fonte de rumo e o filtro de curso existentes, sem duplicar cálculos entre a câmera e o marcador.
- Manter o marcador de posição atualizado independentemente do modo da câmera.

**Non-Goals:**

- Renomear classes, tabelas, eventos, chaves, IDs ou conceitos internos de inspeção.
- Alterar fluxos de ocorrências, plantas, persistência ou sincronização.
- Adicionar sensor de bússola ou dependência externa; a seta representa o rumo confiável da localização ou o curso derivado do deslocamento.
- Replicar a mudança de câmera e marcador em outros mapas nesta entrega.

## Decisions

### 1. Manter um estado explícito de acompanhamento na tela

A tela iniciará em modo de acompanhamento para realizar o foco inicial. Uma interação manual que manipule a câmera desativará esse modo antes de novas animações de localização. `Minha localização` voltará a ativá-lo e executará o foco na amostra atual.

O predicado `isActive` passado ao acompanhamento assíncrono incluirá o estado de acompanhamento, além de montagem da tela e identidade do controller. Assim, uma consulta `getVisibleRegion` que já esteja em andamento não poderá animar a câmera depois que o usuário iniciar a exploração manual. O callback de câmera ociosa poderá atualizar camadas e estado salvo, mas não reativará o acompanhamento por conta própria.

Alternativa considerada: pausar o stream de localização durante a exploração. Foi rejeitada porque congelaria o marcador e reduziria a qualidade da posição usada ao registrar ocorrências.

### 2. Separar atualização do marcador de movimentação da câmera

Cada `UserLocation` válida continuará alimentando o rastreador de curso e provocando a reconstrução do marcador. Somente a chamada que anima a câmera será condicionada ao modo de acompanhamento. O enquadramento manual salvo permanecerá a fonte da posição da câmera quando o widget reconstruir.

Alternativa considerada: ignorar todas as amostras após o primeiro gesto. Foi rejeitada porque deixaria a posição visível desatualizada e contrariaria o uso em campo.

### 3. Expor um rumo filtrado único para câmera e marcador

`UserMapNavigator` disponibilizará o curso filtrado mantido por `UserCourseTracker`, preservando as validações existentes de faixa, velocidade, precisão e deslocamento mínimo. O marcador direcional usará uma imagem com seta e `rotation` em graus geográficos; ele será plano em relação ao mapa para continuar representando o norte corretamente quando a câmera for girada.

Quando o rastreador ainda não possuir curso, a tela usará o indicador neutro de posição, sem orientar a seta para zero por conveniência. A geração dos dois bitmaps permanecerá local e assíncrona, sem novo asset ou pacote.

Alternativa considerada: usar somente o último `heading` bruto. Foi rejeitada porque valores inválidos ou instáveis em baixa velocidade produziriam uma seta enganosa, enquanto o rastreador existente já oferece fallback filtrado.

### 4. Limitar a renomeação à apresentação solicitada

Serão alterados somente o `title` da definição com ID `inspection` e o texto do `AppBar` da tela correspondente. O ID, a navegação, nomes de tipos e textos funcionais como `Inspeções salvas` permanecerão inalterados, evitando uma migração sem benefício funcional.

Alternativa considerada: renomear o domínio inteiro de inspeção. Foi rejeitada por ampliar o risco e contrariar o pedido de mudança apenas no card e no topo da tela.

## Risks / Trade-offs

- [O provedor pode não entregar rumo confiável quando o usuário está parado] → exibir o marcador neutro até haver rumo ou deslocamento suficiente, sem inventar orientação.
- [Um toque simples no mapa pode ser confundido com gesto de câmera] → combinar o sinal de ponteiro com callbacks de movimentação e cobrir toque em marcador e arrasto em testes de widget.
- [Uma animação iniciada antes do gesto pode competir com o usuário] → verificar o estado de acompanhamento novamente após operações assíncronas e antes de animar.
- [A seta pode parecer desalinhada se o bitmap e a âncora não apontarem para zero graus] → desenhar a seta voltada para o norte por padrão e validar rotações cardeais em teste unitário/visual.

## Migration Plan

1. Entregar a alteração de apresentação e os testes de rótulo.
2. Introduzir o estado de acompanhamento e validar foco inicial, gesto manual e recentralização.
3. Expor o curso filtrado e ativar o marcador direcional com fallback neutro.
4. Executar análise estática e a suíte de testes de operações.

Não há migração de dados. O rollback consiste em restaurar o rótulo, o acompanhamento anterior e o bitmap circular; dados locais permanecem compatíveis.
