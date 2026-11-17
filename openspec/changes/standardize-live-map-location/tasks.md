## 1. Infraestrutura compartilhada de localização visual

- [x] 1.1 Alterar a configuração Android do `GeolocatorLocationService` para intervalo desejado de 250 ms, preservando máxima precisão e distância zero em todas as plataformas, e verificar as configurações por testes unitários específicos de plataforma.
- [x] 1.2 Implementar um estado/notifier compartilhado de localização visual que aceite cada amostra recente com coordenadas e precisão válidas, mantenha posição e rumo separados da posição operacional e seja reiniciado entre sessões, verificando validade, atualização abaixo da zona morta operacional, atualização somente de rumo e limpeza com testes unitários.
- [x] 1.3 Generalizar a apresentação neutra/direcional hoje específica de Ocorrências para o componente compartilhado do mapa, preservando ícones, âncora, rotação geográfica e fallback neutro, e verificar rumos cardeais e entradas inválidas em `user_map_navigation_test.dart`.

## 2. Separação entre posição visual e operacional

- [x] 2.1 Integrar o estado visual ao view model de Ocorrências sem alterar a posição estabilizada usada para registro, verificando em teste que uma amostra válida abaixo da zona morta move o marcador mas não substitui a posição operacional.
- [x] 2.2 Integrar o estado visual aos view models de MIPD e atividades, preservando `UserPositionTracker` para decisões funcionais e verificando atualização, pausa, retomada e limpeza nos testes de cada view model.
- [x] 2.3 Integrar o estado visual ao view model de Pulverização, preservando `SprayingLocationFilter` para trilha, distância e gravação, e verificar que amostras visuais adicionais não criam pontos nem alteram totais operacionais.

## 3. Marcador direcional em todos os mapas ao vivo

- [x] 3.1 Migrar Ocorrências para o estado e helper compartilhados sem regressão de câmera livre, recentralização ou marcador, verificando o fluxo existente em `inspection_widgets_test.dart`.
- [x] 3.2 Atualizar MIPD para observar a localização visual e exibir marcador neutro ou direcional com rotação geográfica, verificando posição, rumo e fallback em teste de widget.
- [x] 3.3 Atualizar os mapas principal e de desenho de `ActivityView` para consumir a mesma localização visual e exibir o marcador direcional compartilhado, verificando ambas as superfícies e ausência de reconstrução das camadas estáticas em teste de widget.
- [x] 3.4 Atualizar Pulverização para exibir o marcador direcional compartilhado em todos os estados com localização disponível, mantendo seu comportamento atual de câmera e sessão, e verificar direção, fallback neutro e preservação da trilha em testes.

## 4. Verificação integrada

- [x] 4.1 Executar os testes unitários e de widget de farm, Ocorrências, MIPD, atividades e Pulverização, corrigindo regressões até que a suíte direcionada conclua sem falhas.
- [x] 4.2 Executar `dart analyze` e verificar que a mudança não introduz erros, avisos ou lints.
- [ ] 4.3 Validar em dispositivo a cadência percebida e a seta durante caminhada em Ocorrências, Pulverização, MIPD e ao menos uma atividade, confirmando também que Pomar e Estoque não passaram a iniciar localização e registrando os resultados na mudança.
