## Purpose

Padronizar a atualização visual e a indicação de direção da localização do usuário em todos os mapas operacionais que já utilizam GPS ao vivo.

## ADDED Requirements

### Requirement: Atualizar a localização visual em alta frequência

Enquanto um mapa com localização ao vivo estiver ativo, o aplicativo SHALL solicitar a maior precisão de navegação disponível sem impor filtro de distância e SHALL evitar limitação artificial superior a 250 milissegundos entre solicitações no Android. Em plataformas que controlam a cadência nativamente, o aplicativo SHALL consumir cada amostra disponível sem temporizador adicional. A frequência efetiva MAY variar conforme hardware, sistema operacional e condições do GPS.

#### Scenario: Receber amostras frequentes no Android

- **WHEN** um mapa operacional com localização ao vivo está ativo em um dispositivo Android
- **THEN** o aplicativo solicita amostras com intervalo desejado de 250 milissegundos, máxima precisão de navegação e distância mínima zero

#### Scenario: Receber amostras nas plataformas Apple

- **WHEN** um mapa operacional com localização ao vivo está ativo em uma plataforma Apple
- **THEN** o aplicativo consome continuamente as amostras de máxima precisão entregues pelo sistema sem pausá-las automaticamente nem aplicar temporizador adicional

#### Scenario: Ocultar a superfície do mapa

- **WHEN** a superfície de um mapa operacional deixa de estar ativa
- **THEN** o aplicativo suspende o acompanhamento daquela tela para evitar consumo de bateria sem benefício visual

### Requirement: Separar posição visual de posição operacional

O aplicativo SHALL atualizar o marcador com cada amostra recente e válida para apresentação, sem aguardar o deslocamento mínimo exigido pelos filtros operacionais. Registros, trilhas, distâncias e decisões funcionais SHALL continuar usando a posição estabilizada e os filtros de qualidade próprios de cada operação.

#### Scenario: Caminhar menos que o limiar operacional

- **WHEN** chegam amostras válidas que representam deslocamento real menor que o limiar do filtro usado para gravação
- **THEN** o marcador acompanha as novas posições no mapa
- **AND** nenhum registro operacional é criado até a amostra atender ao filtro de gravação existente

#### Scenario: Receber amostra visual inválida

- **WHEN** uma amostra possui coordenadas inválidas, precisão não confiável ou horário fora da janela aceita
- **THEN** o aplicativo ignora a amostra para o marcador e para o processamento operacional

#### Scenario: Receber atualização somente de rumo

- **WHEN** uma amostra válida mantém a posição dentro da variação visual aceita mas fornece um rumo confiável mais recente
- **THEN** a orientação da seta é atualizada sem exigir um novo registro operacional

### Requirement: Exibir marcador direcional em todos os mapas com GPS ao vivo

O aplicativo SHALL usar a mesma apresentação direcional da posição do usuário em Ocorrências, Pulverização, MIPD e nas atividades baseadas no mapa compartilhado. A seta SHALL priorizar rumo válido fornecido pela localização, SHALL usar curso derivado do deslocamento como fallback e SHALL usar o marcador neutro quando não houver direção confiável.

#### Scenario: Abrir qualquer mapa operacional com rumo confiável

- **WHEN** o usuário abre Ocorrências, Pulverização, MIPD ou uma atividade com mapa e chega uma localização com rumo confiável
- **THEN** o mapa mostra a seta na posição atual orientada para esse rumo

#### Scenario: Derivar direção pelo deslocamento

- **WHEN** o rumo direto está indisponível e as posições válidas demonstram deslocamento suficiente
- **THEN** a seta aponta para o curso geográfico calculado

#### Scenario: Permanecer sem direção confiável

- **WHEN** não existe rumo válido nem deslocamento suficiente para calcular o curso
- **THEN** o mapa mostra o marcador neutro sem afirmar uma direção

#### Scenario: Girar a câmera do mapa

- **WHEN** o usuário gira a câmera enquanto um marcador direcional está visível
- **THEN** a seta continua apontando para o mesmo rumo geográfico

#### Scenario: Usar mapa sem localização ao vivo

- **WHEN** o usuário abre um mapa que atualmente não detecta sua posição, como Pomar ou Estoque
- **THEN** esta mudança não inicia o GPS nem adiciona um marcador do usuário nessa tela
