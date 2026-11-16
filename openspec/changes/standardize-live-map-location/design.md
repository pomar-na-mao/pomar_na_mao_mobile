## Context

Veja `proposal.md` para a motivação e `specs/live-map-location/spec.md` para o contrato observável.

`GeolocatorLocationService` já solicita `bestForNavigation` e `distanceFilter: 0`, mas no Android usa intervalo desejado de um segundo. As telas recebem o mesmo stream e publicam como `userLocation` apenas amostras aceitas por `UserPositionTracker` ou `SprayingLocationFilter`; esses filtros usam estabilização, mediana de três amostras e zona morta de aproximadamente 2,5 a 4 metros. Essa proteção é apropriada para registros e trilhas, porém também limita a fluidez do marcador.

Ocorrências já carrega ícones neutro e direcional e usa `UserCourseTracker`. MIPD, Pulverização e `ActivityView` exibem apenas o ícone neutro. Pulverização possui cálculo próprio de curso para a câmera e `ActivityView` pode manter simultaneamente um mapa principal e uma superfície de desenho. Pomar e Estoque têm mapas, mas não mantêm stream de posição do usuário.

## Goals / Non-Goals

**Goals:**

- Publicar a posição visual com baixa latência sem reutilizá-la automaticamente como posição confiável para persistência.
- Compartilhar validação visual, cálculo de curso e configuração do marcador entre todas as telas em escopo.
- Limitar reconstruções de alta frequência à parte do widget que depende do marcador.
- Preservar o ciclo de vida atual, mantendo o GPS ativo apenas enquanto a superfície relevante estiver ativa.

**Non-Goals:**

- Alterar os filtros que autorizam gravação de ocorrências, trilhas, áreas, rotas ou distâncias.
- Adicionar bússola ou interpretar a orientação física do aparelho; a seta continua representando rumo GPS ou curso de deslocamento.
- Padronizar nesta entrega o comportamento de acompanhamento da câmera de todas as operações.
- Habilitar localização em Pomar, Estoque ou qualquer mapa que hoje não a utiliza.

## Decisions

### 1. Solicitar cadência de 250 ms no Android

O `AndroidSettings.intervalDuration` passará de um segundo para 250 milissegundos, mantendo máxima precisão e distância zero. Em Apple, a configuração continuará com máxima precisão, atividade física, distância zero e pausa automática desabilitada, pois a API não oferece intervalo equivalente; nenhum debounce será adicionado ao stream.

O valor é uma preferência entregue ao provedor, não uma garantia de quatro amostras por segundo. O sistema operacional ainda poderá reduzir a frequência por hardware, energia ou disponibilidade de sinal.

Alternativa considerada: remover `intervalDuration` no Android. Foi rejeitada porque deixa a cadência inteiramente dependente do provedor e dificulta estabelecer e testar a intenção de maior responsividade.

### 2. Criar um canal visual separado do canal operacional

Cada view model em escopo manterá duas saídas derivadas da mesma assinatura de localização:

- a posição visual, atualizada por toda amostra estruturalmente válida, recente e dentro do limite de precisão configurado para a operação;
- a posição operacional existente, atualizada somente após `UserPositionTracker` ou `SprayingLocationFilter` aceitar a amostra.

A saída visual será exposta por um notifier dedicado, permitindo atualizar o marcador sem executar `notifyListeners` no view model inteiro a cada amostra. A posição operacional e seus consumidores atuais permanecerão compatíveis. Falhas e indisponibilidade limparão os dois estados, e pausa/retomada reiniciará os rastreadores para não combinar sessões distintas.

Alternativa considerada: reduzir a zona morta dos filtros existentes. Foi rejeitada porque aumentaria ruído em trilhas e registros e misturaria uma necessidade de apresentação com regras de qualidade operacional.

### 3. Generalizar o controlador e a apresentação do marcador

A apresentação atualmente específica de Ocorrências será movida para o componente compartilhado de navegação do usuário. Um controlador comum receberá amostras visuais, validará frescor/coordenadas/precisão, atualizará `UserCourseTracker` e exporá posição e curso para a tela.

O helper compartilhado escolherá ícone neutro ou direcional e fornecerá `rotation`, `flat` e âncora. Rotação zero continuará apontando para o norte; com curso válido o marcador será plano em relação ao mapa para preservar a direção geográfica após rotação da câmera.

MIPD e Ocorrências usarão o curso do navegador já associado à tela. `ActivityView` alimentará os navegadores das superfícies principal e de desenho com a mesma amostra. Pulverização reutilizará o helper visual compartilhado, mantendo seu rastreador específico para comportamento de câmera e gravação.

Alternativa considerada: copiar a lógica de Ocorrências para cada tela. Foi rejeitada porque duplicaria validações, carregamento de ícones e regras de fallback, aumentando o risco de divergência.

### 4. Reconstruir somente a superfície dependente da localização visual

Os mapas observarão o notifier visual em um `ListenableBuilder`/`ValueListenableBuilder` próximo ao `GoogleMap`. Atualizações de 250 ms não deverão recarregar listas, modais, ações ou consultas de plantas. Camadas de plantas manterão suas revisões e controladores atuais.

Alternativa considerada: chamar `notifyListeners` no view model para cada amostra. Foi rejeitada porque reconstruiria telas operacionais completas até quatro vezes por segundo e poderia neutralizar o ganho de fluidez.

## Risks / Trade-offs

- [Maior frequência aumenta consumo de bateria] → manter assinatura limitada à superfície ativa e cancelar o stream nas pausas já existentes.
- [A posição visual pode oscilar mais que a posição gravada] → aplicar validação de frescor, coordenadas e precisão, sem promover automaticamente a amostra ao canal operacional.
- [Atualizações frequentes podem causar custo de renderização] → isolar o notifier e medir os testes de widget sem reconstruir camadas estáticas.
- [Rumo GPS pode desaparecer em baixa velocidade] → manter curso derivado filtrado e marcador neutro quando não houver evidência confiável.
- [Dois estados de posição podem ser confundidos no código] → usar nomes explícitos para posição visual e operacional e cobrir consumidores de persistência com testes de regressão.

## Migration Plan

1. Generalizar o estado e a apresentação do marcador e migrar Ocorrências sem mudança visual.
2. Adicionar o canal visual separado aos view models e reduzir o intervalo solicitado no Android.
3. Integrar marcador direcional e atualização visual em MIPD, Pulverização e `ActivityView`.
4. Executar testes unitários, de widget, análise estática e validação em dispositivo durante caminhada.

Não há migração de dados. O rollback restaura o intervalo de um segundo e faz cada tela voltar a consumir sua posição operacional e seu marcador anterior; registros persistidos permanecem compatíveis.
