---
name: flutter-operations-feature-pattern
description: "Padroniza funcionalidades Flutter em Operações conforme Pulverização: mapa/GPS, ações, modais, formulários, listas locais, arquitetura, documentação database.md e migrations Supabase. Use ao criar ou refatorar fluxos em Gestão da produção ou Rotina do pomar. Não use para mudanças Flutter sem relação com esse domínio."
---

# Padrão de funcionalidades de Operações

Use a implementação atual de Pulverização como fonte de verdade. Preserve o comportamento e a linguagem visual; não copie valores antigos de documentação quando o código canônico já tiver mudado.

## Fluxo obrigatório

1. Classifique a solicitação entre: mapa/GPS, ações principais, filtros, coleta curta, formulário, lista local/sincronização ou arquitetura/dados.
2. Leia somente as seções correspondentes em [references/ui-patterns.md](references/ui-patterns.md) e, para mudanças de lógica ou dados, [references/architecture.md](references/architecture.md).
3. Abra os arquivos canônicos indicados nas referências antes de editar. Compare estrutura, estados, espaçamentos, cores, ícones e comportamento responsivo.
4. Reutilize componentes e serviços existentes. Se o padrão necessário estiver em widget privado, extraia um componente compartilhado configurável sem alterar a aparência de Pulverização. Evite manter duas cópias que possam divergir.
5. Implemente a menor mudança coerente com as camadas do app.
6. Para toda implementação, atualize obrigatoriamente o `database.md` da raiz nas seções 20 e 25 e crie uma migration `.sql` em `supabase/migrations`. Siga [references/architecture.md](references/architecture.md#documentação-e-migration-obrigatórias).
7. Cubra a lógica com testes unitários e os componentes responsivos/interações importantes com testes de widget.
8. Execute análise estática e os testes afetados. Verifique visualmente larguras estreitas antes de concluir.

## Skills complementares

Antes de fazer julgamento visual, use `ui-ux-pro-max` para validar hierarquia, contraste, densidade, acessibilidade, estados e responsividade, mantendo Pulverização como referência visual final do projeto.

Carregue o menor conjunto aplicável das skills Dart/Flutter disponíveis:

- `flutter-apply-architecture-best-practices` para criar ou reorganizar camadas;
- `flutter-build-responsive-layout` para mapas, barras de ações, formulários e modais adaptáveis;
- `flutter-add-widget-test` para renderização e interação de widgets;
- `dart-add-unit-test` para view models, filtros, geometria e repositórios;
- `dart-run-static-analysis` antes de entregar;
- `flutter-fix-layout-issues` quando houver overflow ou constraints inválidas;
- `supabase` e `supabase-postgres-best-practices` em toda implementação coberta por esta skill, antes de atualizar o contrato de banco, a seção 25 e a migration obrigatória.

As instruções dessas skills complementam este padrão. Quando houver conflito estritamente visual, a implementação atual de Pulverização é a referência do produto.

## Regras inegociáveis

- Não espere o GPS “estabilizar” com overlay ou loading bloqueante. Aceite e refine posições continuamente pela estratégia de filtro descrita na referência.
- Não use o marcador nativo de localização quando o padrão pedir o usuário no mapa; use o círculo azul compartilhado.
- Não coloque regra de negócio, acesso a banco, chamada remota ou filtragem espacial dentro da View.
- Não instancie dependências de produção dentro de widgets. Obtenha-as pelo escopo de injeção do app.
- Não use textos nos botões compactos abaixo do mapa; use ícone, `Tooltip`, semântica e estado visual.
- Não abra teclado automaticamente em seletores ou modais. Campos de pesquisa não recebem foco inicial.
- Não duplique estilos de input, cabeçalhos de bottom sheet, badges de status ou cards locais; extraia e reutilize quando aparecerem em mais de uma funcionalidade.
- Não esconda conteúdo por sobreposição. Título/data, status e ações ocupam regiões próprias e devem continuar legíveis em telas estreitas e com escala de fonte maior.
- Não conclua uma implementação sem manter sincronizados o código, os itens 20 e 25 do `database.md` e uma nova migration em `supabase/migrations`.

## Critérios de conclusão

- O fluxo novo parece pertencer à mesma família de Pulverização sem depender de explicação.
- Mapa, GPS e câmera respeitam ciclo de vida e não continuam ativos sob outra rota.
- Ações quebram linha sem overflow e mantêm alvos de toque adequados.
- Bottom sheets mantêm cabeçalho, raio, altura, fechamento e teclado consistentes.
- Estados locais e de sincronização são explícitos, testáveis e persistidos pelo repositório.
- O fluxo funcional está documentado na seção 20, o contrato executável de banco na seção 25 e a migration correspondente existe e segue o padrão do projeto.
- Streams, timers e controllers são descartados.
- Análise estática e testes afetados passam.
