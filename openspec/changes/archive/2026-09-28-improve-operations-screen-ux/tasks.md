## 1. Estrutura visual e dados

- [x] 1.1 Revisar `OperationDefinition` para incluir descricao curta, status e agrupamento quando necessario; verificar que os cinco itens continuam presentes e Inspecao permanece habilitada.
- [x] 1.2 Refatorar a tela Operacoes em resumo compacto, secao de acao principal e secao de operacoes futuras; verificar manualmente em 320 px que Inspecao aparece sem depender de rolagem longa.
- [x] 1.3 Ajustar ou criar componentes de card para diferenciar acao habilitada e itens futuros; verificar areas de toque >=48 px, texto sem corte e ausencia de emoji como icone.

## 2. Acessibilidade e responsividade

- [x] 2.1 Atualizar semantica dos cards para anunciar nome, estado disponivel/indisponivel e dica de acao; verificar com testes de widget usando `matchesSemantics`.
- [x] 2.2 Garantir que operacoes futuras tenham status textual e nao naveguem ao toque; verificar teste tocando em Pulverizacao, Irrigacao, Colheita e Analise de Solo.
- [x] 2.3 Validar layout em 320 px, 768 px e 1024 px sem rolagem horizontal, sobreposicao ou excecao de renderizacao; verificar por testes de widget responsivos.

## 3. Navegacao e verificacao

- [x] 3.1 Preservar navegacao de Inspecao a partir da acao principal; verificar teste que abre Inspecao e retorna para Operacoes.
- [x] 3.2 Atualizar testes existentes de `operations_view_test.dart` para a nova hierarquia sem depender de detalhes frageis de pixel; verificar `flutter test test/features/operations/operations_view_test.dart`.
- [x] 3.3 Executar analise estatica e testes relevantes; verificar `dart analyze` e os testes de Operacoes sem novas falhas.
