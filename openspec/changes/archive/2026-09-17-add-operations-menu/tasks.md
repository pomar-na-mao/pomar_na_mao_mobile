## 1. Estrutura e comportamento dos cards

- [x] 1.1 Criar os descritores imutáveis das cinco operações e o card reutilizável com título, ícone, cor, disponibilidade, cadeado e texto “Em breve”; verificar com teste de widget que os cinco nomes aparecem e somente Inspeção é anunciada como habilitada.
- [x] 1.2 Implementar semântica e interação dos estados habilitado/bloqueado, mantendo callback nulo nos quatro cards indisponíveis; verificar com testes de semântica e toques que os bloqueados são anunciados como desabilitados e não abrem rota.

## 2. Telas de Operações e Inspeção

- [x] 2.1 Implementar a `OperationsView` com cabeçalho, paleta Material 3, ícones coerentes e grade baseada nas restrições disponíveis; verificar em testes de widget nas larguras 320, 768 e 1024 dp que não há overflow horizontal e que a grade adapta suas colunas.
- [x] 2.2 Implementar a `InspectionView` como nova tela identificada, sem ações de domínio fictícias, e conectar o card Inspeção por `Navigator.push`; verificar com teste de widget que o toque abre o título Inspeção e que o retorno restaura Operações.

## 3. Integração à navegação principal

- [x] 3.1 Adicionar Operações ao `IndexedStack` e à `NavigationBar` entre Fazenda e Sobre, preservando a inicialização preguiçosa da Fazenda; verificar no teste do `MainShell` a ordem Inventário, Fazenda, Operações e Sobre e a seleção correta de cada destino.
- [x] 3.2 Atualizar os testes existentes afetados pelos índices e rótulos da navegação; verificar que navegar por Sobre, Operações e Inventário preserva o estado e não aumenta indevidamente as cargas do repositório de Inventário.

## 4. Qualidade e validação

- [x] 4.1 Revisar contraste, alvos de toque mínimos de 48 dp, indicadores não dependentes de cor e uso consistente de ícones Material; verificar visualmente nos temas suportados e por assertions de semântica nos testes.
- [x] 4.2 Formatar os arquivos Dart alterados e executar `flutter analyze`; verificar que o comando termina sem erros ou avisos introduzidos pela mudança.
- [x] 4.3 Executar os testes de widget de Operações e do `MainShell`, seguidos da suíte Flutter completa; verificar que todos os testes terminam com sucesso.
