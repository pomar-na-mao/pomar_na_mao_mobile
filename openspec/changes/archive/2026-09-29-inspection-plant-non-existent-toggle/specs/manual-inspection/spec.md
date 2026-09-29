## MODIFIED Requirements

### Requirement: Editar ocorrências independentemente por planta
Tocar em uma planta individual SHALL abrir um modal identificado pela planta, apresentando no topo da tela um controle toggle "Planta Inexistente" posicionado acima da lista de ocorrências, seguido por todos os tipos de ocorrência por nome com indicadores circulares marcáveis independentemente. O toggle "Planta Inexistente" SHALL iniciar ativo se `non_existent` for `true` e desativado se for `false`. O estado inicial das ocorrências SHALL considerar ocorrências `open` e alterações locais ainda não sincronizadas; ocorrências `resolved` ou `ignored` SHALL NOT aparecer marcadas. A acessibilidade SHALL anunciar seleção múltipla e estado marcado/desmarcado de ocorrências e o estado do toggle de planta inexistente, sem comportamento de grupo radio exclusivo.

#### Scenario: Selecionar planta após zoom
- **WHEN** o usuário aproxima o mapa e toca no marcador de uma planta
- **THEN** o editor apresenta o estado daquela planta, o toggle "Planta Inexistente" no topo com seu estado correspondente e todas as opções do catálogo
- **AND** tocar em um agrupamento, se utilizado, aproxima o mapa em vez de editar uma planta arbitrária

#### Scenario: Alternar toggle de planta inexistente
- **WHEN** o usuário abre o modal de uma planta com `non_existent = false` e aciona o toggle "Planta Inexistente"
- **THEN** o toggle passa para ativo e a alteração é mantida no estado em edição
- **AND** o botão Atualizar é habilitado para confirmar a modificação da planta

#### Scenario: Marcar e desmarcar múltiplas ocorrências
- **WHEN** o usuário marca duas ocorrências e toca novamente na primeira
- **THEN** a primeira fica desmarcada, a segunda permanece marcada e cada transição é persistida localmente

#### Scenario: Reabrir editor ou falhar ao persistir
- **WHEN** o usuário fecha e reabre o editor após uma alteração confirmada localmente
- **THEN** o estado editado (incluindo o toggle "Planta Inexistente" e ocorrências) é restaurado
- **AND** se uma nova gravação local falhar, a tela informa o erro e não apresenta essa alteração como salva

### Requirement: Manter Atualizar visível e finalizar todas as alterações
O modal da planta SHALL manter o botão Atualizar visível em rodapé fora da lista rolável. A ação SHALL finalizar a inspeção corrente com todas as plantas alteradas (seja por ocorrências ou por alteração no toggle "Planta Inexistente"), inclusive outras plantas editadas anteriormente, após concluir as gravações locais. Sem alterações pendentes ou durante envio, a ação SHALL ficar desabilitada.

#### Scenario: Finalizar alterações de duas plantas
- **WHEN** o usuário altera A, fecha seu modal, altera B e toca em Atualizar
- **THEN** uma única inspeção é finalizada no SQLite contendo as alterações de A e B, e o aplicativo tenta sincronizá-la
- **AND** a tela informa sucesso remoto ou salvamento local pendente sem confundir os dois resultados

#### Scenario: Finalizar alteração exclusiva de planta inexistente
- **WHEN** o usuário apenas altera o toggle "Planta Inexistente" de uma planta sem adicionar ou remover ocorrências e toca em Atualizar
- **THEN** a inspeção é finalizada com a alteração dessa planta e preparada para sincronização

#### Scenario: Catálogo extenso
- **WHEN** o usuário rola uma lista de ocorrências maior que a área do modal
- **THEN** Atualizar permanece visível e a última ocorrência pode ser alcançada sem ficar atrás do rodapé

#### Scenario: Continuar após finalização
- **WHEN** o usuário volta a editar após finalizar uma inspeção, mesmo que ela esteja pendente de envio
- **THEN** as novas alterações pertencem a uma nova inspeção e não modificam o lote já finalizado

### Requirement: Exibir plantas inexistentes no mapa com cor diferenciada
As plantas com `non_existent = true` SHALL ser exibidas no mapa de inspeção com marcador na cor amarela/dourada (#F9A825), enquanto plantas existentes (`non_existent = false`) utilizam o marcador verde (#2E7D32). Ambas SHALL permanecer interagíveis para abertura do modal de inspeção.

#### Scenario: Visualizar planta inexistente no mapa
- **WHEN** o usuário visualiza o mapa da inspeção e existem plantas marcadas como `non_existent = true`
- **THEN** essas plantas são renderizadas no mapa com o ícone amarelo (#F9A825)
- **AND** tocar no marcador abre o editor da planta com o toggle "Planta Inexistente" ativo

