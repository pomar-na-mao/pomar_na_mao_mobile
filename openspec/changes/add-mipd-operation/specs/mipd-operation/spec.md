## Purpose

Definir a experiência de campo do MIPD, com mapa coerente com a Inspeção, registro fitossanitário por planta e captura opcional de evidência fotográfica.

## ADDED Requirements

### Requirement: Apresentar o mapa MIPD com paridade visual e operacional

O aplicativo SHALL apresentar na tela MIPD o mesmo enquadramento, controles, posição do usuário, cores, formatos de marcador, regras de agrupamento, níveis de detalhe e estratégia de renderização usados pela Inspeção. O MIPD SHALL consumir a mesma revisão local compartilhada de plantas e SHALL manter a interação responsiva nos mesmos volumes suportados pela Inspeção.

#### Scenario: Abrir o MIPD com plantas em cache
- **WHEN** o usuário abre o MIPD e existe uma revisão local íntegra de plantas
- **THEN** o sistema exibe as plantas e a posição disponível do usuário com a mesma apresentação e comportamento do mapa da Inspeção
- **AND** não inicia uma leitura remota apenas por abrir a tela

#### Scenario: Atualizar a localização do usuário
- **WHEN** o provedor de localização entrega uma nova posição válida durante o uso do MIPD
- **THEN** o mapa atualiza o indicador do usuário segundo as mesmas regras de precisão, frequência e câmera adotadas pela Inspeção

#### Scenario: Renderizar um conjunto grande de plantas
- **WHEN** a revisão local contém o volume máximo de plantas suportado pela Inspeção
- **THEN** o MIPD aplica a mesma estratégia de preparação, agrupamento e renderização incremental sem bloquear a interação

### Requirement: Oferecer ações principais abaixo do mapa

O aplicativo SHALL apresentar abaixo do mapa um card de ações com os botões Carregar Plantas e Marcações salvas, nessa ordem, usando os mesmos padrões visuais, responsivos, semânticos e de estado da Inspeção.

#### Scenario: Visualizar as ações do MIPD
- **WHEN** o usuário abre a tela MIPD
- **THEN** o card abaixo do mapa exibe Carregar Plantas e Marcações salvas com áreas de toque acessíveis e sem sobreposição

#### Scenario: Abrir as marcações salvas
- **WHEN** o usuário toca em Marcações salvas
- **THEN** o sistema abre a lista local de apontamentos MIPD preservando o estado do mapa para retorno

### Requirement: Atualizar os dados compartilhados explicitamente

Ao acionar Carregar Plantas no MIPD, o aplicativo SHALL executar a atualização completa e atômica dos dados compartilhados necessários às operações, incluindo plantas, fazenda, zonas, regiões, catálogo de tipos de ocorrência e estado remoto de ocorrências abertas. A atualização SHALL obedecer à política de `local-read-cache` e SHALL preservar a última revisão íntegra em caso de falha.

#### Scenario: Atualizar todos os dados com sucesso
- **WHEN** o usuário toca em Carregar Plantas no MIPD e todas as leituras remotas terminam com sucesso
- **THEN** o sistema publica uma única nova revisão local completa para todos os consumidores
- **AND** o MIPD passa a usar o catálogo atualizado de pragas e doenças

#### Scenario: Falhar durante a atualização
- **WHEN** qualquer parte da atualização falha e existe uma revisão local anterior
- **THEN** o sistema mantém a revisão anterior disponível e informa uma falha recuperável sem publicar dados parciais

### Requirement: Abrir uma marcação a partir da planta

O aplicativo SHALL abrir um modal de marcação MIPD ao tocar em uma planta interativa do mapa. O modal SHALL identificar a planta selecionada, oferecer uma seleção única de praga ou doença e uma seleção múltipla obrigatória de partes da planta.

#### Scenario: Tocar em uma planta
- **WHEN** o usuário toca em uma planta interativa no mapa MIPD
- **THEN** o sistema abre o modal associado àquela planta sem alterar silenciosamente outra marcação

#### Scenario: Fechar sem salvar
- **WHEN** o usuário cancela ou fecha o modal antes de salvar
- **THEN** nenhuma nova marcação local é persistida

### Requirement: Listar exclusivamente pragas e doenças

O campo de praga ou doença SHALL listar somente registros do catálogo local `occurrence_types` cuja `category` seja exatamente `PEST_DISEASE`. A escolha SHALL ser única e obrigatória, e o filtro SHALL ser aplicado pelo consumidor mesmo quando o cache compartilhado contiver outras categorias.

#### Scenario: Abrir o seletor fitossanitário
- **WHEN** o usuário abre o campo de praga ou doença
- **THEN** o sistema mostra todos e somente os tipos de ocorrência com categoria `PEST_DISEASE`

#### Scenario: Catálogo não contém praga ou doença
- **WHEN** o catálogo local está íntegro mas não contém registros `PEST_DISEASE`
- **THEN** o modal informa que não há opções disponíveis e impede o salvamento até uma atualização válida

### Requirement: Selecionar uma ou mais partes da planta

O campo Parte da planta SHALL permitir selecionar uma ou mais opções entre Folha, Ramo, Tronco, Raiz e Fruto. Pelo menos uma parte SHALL ser obrigatória, e as opções selecionadas SHALL permanecer visíveis e removíveis antes do salvamento.

#### Scenario: Selecionar múltiplas partes
- **WHEN** o usuário seleciona Folha e Fruto
- **THEN** ambas permanecem selecionadas e serão associadas à mesma marcação

#### Scenario: Tentar salvar sem parte selecionada
- **WHEN** o usuário escolhe uma praga ou doença mas não seleciona nenhuma parte
- **THEN** o sistema não salva e apresenta a validação do campo Parte da planta

### Requirement: Capturar uma foto opcional pela câmera

O modal SHALL apresentar abaixo de Parte da planta um card pontilhado com ação para abrir a câmera. A foto SHALL ser opcional; quando capturada, sua pré-visualização SHALL ocupar o espaço reservado e SHALL permitir nova captura ou remoção antes de salvar.

#### Scenario: Capturar uma foto
- **WHEN** o usuário aciona a câmera, concede permissão e confirma a imagem
- **THEN** o modal mostra a pré-visualização da foto no card reservado

#### Scenario: Cancelar ou negar a câmera
- **WHEN** o usuário cancela a captura ou nega a permissão da câmera
- **THEN** o modal permanece utilizável, informa o estado quando necessário e permite salvar sem foto

#### Scenario: Remover a foto antes de salvar
- **WHEN** o usuário remove a foto capturada
- **THEN** o card volta ao estado pontilhado e a marcação poderá ser salva sem imagem

### Requirement: Salvar a marcação localmente

O aplicativo SHALL habilitar Salvar somente quando houver planta, uma ocorrência `PEST_DISEASE` e ao menos uma parte válida. Ao confirmar, SHALL persistir a marcação e a eventual foto em armazenamento local durável antes de fechar o modal, sem exigir conectividade.

#### Scenario: Salvar offline sem foto
- **WHEN** os campos obrigatórios são válidos, não há foto e o dispositivo está offline
- **THEN** o sistema persiste a marcação como pendente, fecha o modal e a disponibiliza em Marcações salvas

#### Scenario: Falhar ao persistir localmente
- **WHEN** a gravação da marcação ou da foto local falha
- **THEN** o modal permanece aberto, informa a falha e não apresenta o item como salvo

