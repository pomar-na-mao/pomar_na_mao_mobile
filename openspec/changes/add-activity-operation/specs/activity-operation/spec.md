## Purpose

Permitir que o usuário registre no mapa uma atividade de campo associada a uma rota ou área desenhada, com data, responsável e uma calda cadastrada quando aplicável.

## ADDED Requirements

### Requirement: Apresentar o mapa da Atividade

O aplicativo SHALL apresentar uma tela identificada coma Atividade com o mesmo tipo de mapa, enquadramento inicial, localização do usuário, estilo, marcadores de plantas, agrupamento e estratégia de renderização usados pelas operações cartográficas existentes. A abertura SHALL priorizar a revisão local íntegra e SHALL NOT exigir rede quando houver dados em cache.

#### Scenario: Abrir com plantas em cache
- **WHEN** o usuário abre a Atividade e existe uma revisão local íntegra de plantas
- **THEN** o sistema exibe o mapa, as plantas e a localização disponível do usuário sem iniciar uma leitura remota apenas pela abertura

#### Scenario: Abrir sem plantas em cache
- **WHEN** o usuário abre a Atividade sem uma revisão local de plantas
- **THEN** o sistema mantém o mapa utilizável, apresenta um estado recuperável para carregar os dados e não impede o desenho da geometria

#### Scenario: Renderizar grande quantidade de plantas
- **WHEN** o cache contém o volume máximo de plantas suportado pelas operações existentes
- **THEN** a Atividade aplica a mesma limitação por viewport, agrupamento e renderização incremental sem bloquear o desenho

### Requirement: Escolher o tipo de geometria antes do desenho

O aplicativo SHALL oferecer modos mutuamente exclusivos Rota e Área. Rota SHALL produzir uma linha ordenada e Área SHALL produzir um anel fechado, mantendo sempre visível qual modo está ativo.

#### Scenario: Selecionar Rota
- **WHEN** o usuário seleciona o modo Rota
- **THEN** os próximos pontos desenhados compõem uma linha ordenada e o sistema não fecha automaticamente a geometria como área

#### Scenario: Selecionar Área
- **WHEN** o usuário seleciona o modo Área
- **THEN** os próximos pontos desenhados compõem o contorno de um polígono e a prévia visual fecha o último ponto no primeiro

#### Scenario: Trocar o modo com desenho existente
- **WHEN** o usuário tenta trocar entre Rota e Área depois de iniciar um desenho
- **THEN** o sistema solicita confirmação antes de descartar os pontos incompatíveis e mantém o desenho se a troca for cancelada

### Requirement: Desenhar e editar a geometria com gestos no mapa

O aplicativo SHALL converter a interação manual no mapa em vértices geográficos ordenados, exibir a prévia da linha ou polígono sobre o mapa e oferecer ações para desfazer o último ponto e limpar o desenho. Enquanto o gesto de desenho estiver ativo, o sistema SHALL evitar que a mesma interação mova a câmera acidentalmente.

#### Scenario: Desenhar uma rota
- **WHEN** o usuário traça ou adiciona pontos no modo Rota
- **THEN** o sistema mostra uma linha conectando os vértices na ordem informada

#### Scenario: Desenhar uma área
- **WHEN** o usuário traça ou adiciona pontos no modo Área
- **THEN** o sistema mostra o contorno e o preenchimento translúcido da área, fechando visualmente o último vértice no primeiro

#### Scenario: Desfazer o último ponto
- **WHEN** o usuário aciona Desfazer com pelo menos um ponto desenhado
- **THEN** o último vértice é removido e a prévia é recalculada sem afetar os pontos anteriores

#### Scenario: Limpar o desenho
- **WHEN** o usuário confirma a ação Limpar
- **THEN** todos os vértices são removidos e o modo selecionado permanece pronto para um novo desenho

### Requirement: Validar a geometria antes do formulário

O aplicativo SHALL aceitar uma rota somente com pelo menos dois pontos distintos e SHALL aceitar uma área somente com pelo menos três vértices distintos e o primeiro ponto repetido como posição final, totalizando ao menos quatro posições no anel. O sistema SHALL rejeitar coordenadas inválidas, segmentos de comprimento nulo e polígonos autointersectantes.

#### Scenario: Tentar continuar com rota insuficiente
- **WHEN** o desenho de Rota contém menos de dois pontos distintos
- **THEN** o sistema não abre a confirmação e informa que a rota precisa de pelo menos dois pontos

#### Scenario: Tentar continuar com área insuficiente
- **WHEN** o desenho de Área contém menos de três vértices distintos
- **THEN** o sistema não abre a confirmação e informa que a área precisa de pelo menos três vértices e fechamento

#### Scenario: Fechar uma área válida
- **WHEN** o desenho contém pelo menos três vértices distintos sem autointerseção
- **THEN** o sistema gera um anel com o primeiro ponto também na posição final e permite continuar

#### Scenario: Detectar autointerseção
- **WHEN** os segmentos não adjacentes do contorno se cruzam
- **THEN** o sistema destaca a geometria inválida, impede o salvamento e orienta o usuário a ajustar ou refazer o desenho

### Requirement: Preencher os dados da atividade

Após uma geometria válida, o aplicativo SHALL abrir um formulário seguindo o padrão de modal das operações existentes com os campos Atividade realizada, Data, Hora e Responsável. Todos esses campos SHALL ser obrigatórios; Data e Hora SHALL compor um único instante usando o fuso local do dispositivo e SHALL permanecer editáveis antes de salvar.

#### Scenario: Abrir o formulário
- **WHEN** o usuário confirma uma geometria válida
- **THEN** o modal exibe a prévia do tipo de geometria e os campos Atividade realizada, Data, Hora, Responsável e Calda

#### Scenario: Informar atividade manual
- **WHEN** o usuário preenche Atividade realizada com `roçagem`
- **THEN** o valor textual é preservado para o lançamento sem exigir seleção em catálogo

#### Scenario: Compor data e hora
- **WHEN** o usuário escolhe `30/10/2026` e informa `12:30`
- **THEN** o sistema apresenta ambos os valores e prepara um único instante correspondente no fuso local para persistência

#### Scenario: Tentar salvar campo obrigatório vazio
- **WHEN** atividade, data, hora ou responsável está ausente ou contém apenas espaços
- **THEN** o sistema mantém o modal aberto, identifica cada campo inválido e não cria o lançamento

### Requirement: Selecionar uma máquina ou trator cadastrado

O formulário SHALL permitir selecionar no máximo uma opção de `public.machines`. A seleção SHALL ser opcional e SHALL apresentar nome, marca e ano disponíveis somente para leitura. O usuário SHALL poder selecionar, trocar ou remover a associação antes de salvar, sem editar qualquer informação do catálogo.

#### Scenario: Selecionar uma máquina
- **WHEN** o usuário escolhe uma máquina ou trator cadastrado
- **THEN** o equipamento é associado ao lançamento e seus dados são exibidos somente para consulta

#### Scenario: Registrar sem máquina
- **WHEN** a atividade não utiliza máquina e os demais campos estão válidos
- **THEN** o sistema permite salvar o lançamento sem referência de máquina

### Requirement: Selecionar uma calda cadastrada

O formulário SHALL permitir selecionar no máximo uma calda ativa do catálogo local originado de `public.mixtures`. A seleção SHALL exibir o nome da calda, observações disponíveis e sua composição de `public.mixture_inputs`, incluindo nome do insumo, princípio ativo, dose e unidade. Nenhuma informação da calda — nome, observações, composição, insumos, doses ou unidades — SHALL ser editável. O usuário poderá somente selecionar, trocar ou remover a associação da calda antes de salvar a atividade.

#### Scenario: Pesquisar e selecionar uma calda
- **WHEN** o usuário abre o seletor e escolhe uma calda ativa
- **THEN** a calda é associada ao lançamento e sua composição completa é exibida somente para consulta

#### Scenario: Trocar a calda selecionada
- **WHEN** o usuário abre novamente o seletor e escolhe outra calda
- **THEN** a seleção anterior e sua composição são substituídas integralmente pela nova receita

#### Scenario: Remover a calda
- **WHEN** o usuário remove a calda selecionada antes de salvar
- **THEN** o lançamento deixa de referenciar a receita sem alterar `public.mixtures` ou `public.mixture_inputs`

#### Scenario: Registrar atividade sem calda
- **WHEN** a atividade não utiliza calda e os demais campos estão válidos
- **THEN** o sistema permite salvar o lançamento sem calda e sem componentes

### Requirement: Salvar o lançamento localmente

O aplicativo SHALL persistir a geometria, atividade, instante, responsável, referência e snapshots da máquina, da calda e de sua composição em armazenamento local durável antes de fechar o formulário. O lançamento SHALL receber um identificador local estável e estado pendente, inclusive sem conectividade.

#### Scenario: Salvar offline
- **WHEN** geometria e campos obrigatórios são válidos e o dispositivo está offline
- **THEN** o sistema salva o lançamento como pendente, fecha o modal e o disponibiliza na lista local

#### Scenario: Falhar ao persistir localmente
- **WHEN** qualquer parte da gravação local transacional falha
- **THEN** o modal permanece aberto, a falha é informada e nenhum lançamento parcial aparece como salvo

#### Scenario: Consultar lançamentos salvos
- **WHEN** o usuário abre a lista da Atividade
- **THEN** o sistema mostra os lançamentos locais com atividade, data, responsável, tipo de geometria, nomes da máquina e da calda quando houver e estado de sincronização

### Requirement: Filtrar plantas por zona nos mapas da Atividade

A tela inicial da Atividade SHALL disponibilizar, imediatamente à direita da ação Carregar plantas, o filtro de zonas com a mesma apresentação e interação adotadas pela operação de Pulverização. Ao selecionar uma zona, o aplicativo SHALL exibir apenas suas plantas, destacar seu contorno e enquadrá-la tanto no mapa inicial quanto ao abrir o modal de desenho. Depois do enquadramento inicial, atualizações da localização do usuário SHALL NOT reposicionar ou alterar o zoom do mapa de desenho.

#### Scenario: Selecionar uma zona
- **WHEN** o usuário abre Filtros de Plantas e seleciona uma zona
- **THEN** o mapa inicial mostra somente as plantas associadas, apresenta o filtro ativo e ajusta a câmera para enquadrar o contorno da zona

#### Scenario: Abrir o desenho com zona filtrada
- **WHEN** o usuário seleciona uma zona e abre o modal Desenhar operação
- **THEN** o mapa de desenho inicia enquadrando o contorno da zona selecionada e permanece livre para movimentação manual posterior

#### Scenario: Limpar o filtro
- **WHEN** o usuário limpa a zona selecionada
- **THEN** todas as plantas carregadas voltam a ser exibidas e o filtro deixa de aparecer como ativo

### Requirement: Manter controles do desenho em uma linha

O modal Desenhar operação SHALL apresentar Mover mapa/Desenhando, Desfazer, Limpar e Continuar na mesma linha, inclusive na largura mínima suportada de 320 px, preservando alvos de toque acessíveis.

#### Scenario: Abrir o desenho em tela estreita
- **WHEN** o usuário abre o modal em um dispositivo com 320 px de largura
- **THEN** todos os controles de desenho permanecem na mesma linha e não ocorre overflow de layout
