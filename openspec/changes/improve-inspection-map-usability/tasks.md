## 1. Renomeação da interface

- [x] 1.1 Atualizar o primeiro item de `operationModules` para exibir `Ocorrências`, preservando ID, descrição, ordem e navegação, e verificar em `operations_view_test.dart` que somente esse rótulo foi alterado.
- [x] 1.2 Atualizar o título do `AppBar` da rotina para `Ocorrências`, sem renomear textos funcionais de inspeção, e verificar em `inspection_widgets_test.dart` a presença do título junto ao botão de voltar.

## 2. Controle da câmera durante exploração manual

- [x] 2.1 Introduzir um estado testável de acompanhamento da localização que inicia ativo, é suspenso por manipulação manual e é reativado por recentralização, verificando as transições com testes unitários.
- [x] 2.2 Condicionar todas as animações automáticas de localização ao estado de acompanhamento, inclusive após consultas assíncronas da região visível, e verificar que um gesto iniciado durante uma consulta pendente impede a animação.
- [x] 2.3 Integrar os callbacks de gesto, movimento e repouso do mapa sem confundir animações programáticas ou toques em marcadores com arrasto, e verificar em teste de widget que novas posições atualizam o marcador sem desfazer a câmera escolhida manualmente.
- [x] 2.4 Fazer `Minha localização` recentralizar e reativar o acompanhamento até o próximo gesto manual, verificando o ciclo completo de explorar, recentralizar, acompanhar e explorar novamente em teste de widget.

## 3. Marcador direcional do usuário

- [x] 3.1 Expor pelo navegador do mapa o curso filtrado produzido pelo rastreador existente e verificar com testes unitários rumo direto válido, fallback por deslocamento, rejeição de valores inválidos e ausência inicial de curso.
- [x] 3.2 Criar o bitmap direcional apontando para o norte em rotação zero e manter um bitmap neutro para rumo indisponível, verificando dimensões, âncora e seleção do ícone sem adicionar assets ou dependências.
- [x] 3.3 Configurar o marcador da rotina com rotação geográfica e comportamento plano no mapa quando houver curso, preservando a posição e a câmera livre, e verificar os rumos cardeais e o fallback neutro em testes da configuração do mapa.

## 4. Verificação integrada

- [x] 4.1 Executar os testes unitários e de widget de operações, corrigindo regressões até que a suíte direcionada conclua sem falhas.
- [x] 4.2 Executar `dart analyze` e verificar que a mudança não introduz erros, avisos ou lints.
- [ ] 4.3 Validar manualmente em dispositivo a exploração de plantas distantes, a recentralização e a orientação da seta durante deslocamento, registrando o resultado nos artefatos da mudança.
