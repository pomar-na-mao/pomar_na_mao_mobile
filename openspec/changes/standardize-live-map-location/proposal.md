## Why

Os mapas operacionais que exibem a posição do usuário atualizam o marcador com cadências e estilos diferentes, o que torna o acompanhamento em campo menos fluido e deixa a direção disponível apenas em Ocorrências. É necessário padronizar a localização ao vivo para responder mais rapidamente ao deslocamento sem comprometer a qualidade dos dados registrados.

## What Changes

- Solicitar atualizações de localização em alta frequência enquanto um mapa operacional ativo estiver visível, usando intervalo desejado de 250 ms no Android e o fluxo contínuo de máxima precisão disponível nas plataformas Apple.
- Separar a posição visual de baixa latência da posição estabilizada usada para registros, trilhas e cálculos funcionais, evitando que a maior fluidez enfraqueça os filtros de qualidade existentes.
- Reutilizar o marcador direcional com rumo filtrado e fallback neutro em todos os mapas que já detectam a posição do usuário: Ocorrências, Pulverização, MIPD e atividades baseadas em `ActivityView`.
- Manter a direção geográfica correta quando a câmera girar e continuar atualizando o marcador mesmo quando o usuário explorar o mapa manualmente.
- Não ativar localização em mapas que hoje não a detectam, como Pomar e Estoque, nem adicionar leitura de bússola independente do GPS.

## Capabilities

### New Capabilities

- `live-map-location`: define a cadência, a separação entre posição visual e posição operacional e a representação direcional comum nos mapas com localização ao vivo.

### Modified Capabilities

Nenhuma.

## Impact

- Configuração compartilhada de `GeolocatorLocationService` e publicação de amostras para apresentação.
- Filtros e view models de Ocorrências, Pulverização, MIPD e atividades, preservando os filtros usados para persistência e trilhas.
- Componentes compartilhados do marcador do usuário e integrações em `InspectionView`, `SprayingView`, `MipdView` e `ActivityView`.
- Testes unitários, de widget e validação em dispositivo de cadência, fallback neutro e rotações direcionais.
- Maior consumo de bateria enquanto mapas com localização ao vivo estiverem ativos; o stream continuará pausado quando a superfície do mapa não estiver ativa.
