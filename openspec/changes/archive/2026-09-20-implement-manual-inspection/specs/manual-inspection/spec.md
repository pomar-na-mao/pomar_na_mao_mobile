## Purpose

Permitir a inspeção manual de plantas no mapa, com localização do usuário e edição independente de ocorrências durante o trabalho no pomar.

## ADDED Requirements

### Requirement: Iniciar com mapa e localização
O aplicativo SHALL renderizar o mapa ao abrir Inspeção, solicitar acesso à localização quando necessário e marcar a posição real do usuário quando disponível. Plantas SHALL ser carregadas somente pela ação explícita ou pela retomada de uma inspeção local.

#### Scenario: Abrir com GPS disponível
- **WHEN** o usuário abre Inspeção e a localização está disponível
- **THEN** o mapa é centralizado inicialmente no usuário, sua posição é indicada e a tela permite zoom e deslocamento
- **AND** as atualizações de posição não desfazem o enquadramento escolhido manualmente

#### Scenario: Localização indisponível
- **WHEN** a permissão é negada, o GPS está desligado ou ocorre falha na localização
- **THEN** a tela informa a indisponibilidade e oferece nova tentativa, mantendo mapa e ações utilizáveis sem inventar uma posição

### Requirement: Apresentar três ações entre mapa e navegação
O aplicativo SHALL apresentar um card com os botões Carregar plantas, Ocorrências e Inspeções salvas, nesta ordem, abaixo do mapa e acima da navegação inferior. O layout SHALL respeitar áreas seguras, texto ampliado, contraste e alvos de toque de pelo menos 48 unidades lógicas.

#### Scenario: Usar janela compacta ou ampla
- **WHEN** a tela é exibida em larguras de 320, 768 ou 1024 unidades lógicas
- **THEN** as três ações permanecem legíveis e acessíveis, sem sobreposição com o mapa ou a navegação e sem rolagem horizontal

### Requirement: Carregar plantas existentes
A ação Carregar plantas SHALL consultar `plants` com o filtro remoto `non_existent = false`, obter todas as páginas e disponibilizar marcadores individuais nas coordenadas válidas. O carregamento SHALL incluir o catálogo de ocorrências e o estado de ocorrências abertas das plantas para permitir edição correta offline. Dados incompletos SHALL NOT ser tratados como ausência de ocorrências.

#### Scenario: Resultado maior que uma página
- **WHEN** a consulta retorna mais plantas que o limite de uma página
- **THEN** todas as páginas são carregadas e todas as plantas elegíveis com coordenadas válidas ficam disponíveis no mapa
- **AND** plantas com `non_existent = true` não são exibidas

#### Scenario: Consulta vazia ou falha sem cache
- **WHEN** a consulta termina vazia ou falha sem dados locais utilizáveis
- **THEN** a tela distingue Nenhuma planta encontrada de falha de carregamento, encerra o indicador de progresso e permite tentar novamente

#### Scenario: Trabalhar com dados já carregados
- **WHEN** o dispositivo está offline e existe um conjunto local completo de plantas, tipos e ocorrências
- **THEN** o aplicativo permite retomar esse conjunto e informa que os dados são locais
- **AND** não substitui alterações pendentes durante novas tentativas de carregamento

### Requirement: Consultar catálogo e imprimir código
O botão Ocorrências SHALL abrir um modal com as opções de `occurrence_types`, exibindo `name`. Selecionar uma opção SHALL imprimir exclusivamente seu `code` como mensagem de diagnóstico, sem prefixo, nome, UUID ou objeto serializado, e fechar o modal. Essa ação SHALL NOT alterar plantas, filtrar o mapa ou definir o alvo da inspeção.

#### Scenario: Selecionar uma ocorrência
- **WHEN** o usuário escolhe a opção cujo nome é Galho Seco e cujo código é `stick`
- **THEN** o aplicativo emite a mensagem `stick` e fecha o modal
- **AND** não cria alterações de inspeção

#### Scenario: Catálogo indisponível
- **WHEN** o catálogo não pode ser obtido e não existe cache
- **THEN** o modal apresenta erro com nova tentativa, sem opções fictícias

### Requirement: Editar ocorrências independentemente por planta
Tocar em uma planta individual SHALL abrir um modal identificado pela planta, com todos os tipos de ocorrência por nome e indicadores circulares marcáveis independentemente. O estado inicial SHALL considerar ocorrências `open` e alterações locais ainda não sincronizadas; ocorrências `resolved` ou `ignored` SHALL NOT aparecer marcadas. A acessibilidade SHALL anunciar seleção múltipla e estado marcado/desmarcado, sem comportamento de grupo radio exclusivo.

#### Scenario: Selecionar planta após zoom
- **WHEN** o usuário aproxima o mapa e toca no marcador de uma planta
- **THEN** o editor apresenta o estado daquela planta e todas as opções do catálogo
- **AND** tocar em um agrupamento, se utilizado, aproxima o mapa em vez de editar uma planta arbitrária

#### Scenario: Marcar e desmarcar múltiplas ocorrências
- **WHEN** o usuário marca duas ocorrências e toca novamente na primeira
- **THEN** a primeira fica desmarcada, a segunda permanece marcada e cada transição é persistida localmente

#### Scenario: Reabrir editor ou falhar ao persistir
- **WHEN** o usuário fecha e reabre o editor após uma alteração confirmada localmente
- **THEN** o estado editado é restaurado
- **AND** se uma nova gravação local falhar, a tela informa o erro e não apresenta essa alteração como salva

### Requirement: Manter Atualizar visível e finalizar todas as alterações
O modal da planta SHALL manter o botão Atualizar visível em rodapé fora da lista rolável. A ação SHALL finalizar a inspeção corrente com todas as plantas alteradas, inclusive outras plantas editadas anteriormente, após concluir as gravações locais. Sem alterações ou durante envio, a ação SHALL ficar desabilitada.

#### Scenario: Finalizar alterações de duas plantas
- **WHEN** o usuário altera A, fecha seu modal, altera B e toca em Atualizar
- **THEN** uma única inspeção é finalizada no SQLite contendo as alterações de A e B, e o aplicativo tenta sincronizá-la
- **AND** a tela informa sucesso remoto ou salvamento local pendente sem confundir os dois resultados

#### Scenario: Catálogo extenso
- **WHEN** o usuário rola uma lista de ocorrências maior que a área do modal
- **THEN** Atualizar permanece visível e a última ocorrência pode ser alcançada sem ficar atrás do rodapé

#### Scenario: Continuar após finalização
- **WHEN** o usuário volta a editar após finalizar uma inspeção, mesmo que ela esteja pendente de envio
- **THEN** as novas alterações pertencem a uma nova inspeção e não modificam o lote já finalizado
