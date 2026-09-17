## Context

O `MainShell` atual usa `IndexedStack` e `NavigationBar` para manter três destinos, com Fazenda inicializada sob demanda no índice 1. A nova área não depende de estado remoto nem de backend e deve entrar no mesmo shell sem alterar a inicialização preguiçosa da Fazenda. Consulte `proposal.md` para a motivação e `specs/` para os comportamentos exigidos.

A interface existente usa Material 3, `ColorScheme.fromSeed` verde e componentes com cantos discretamente arredondados. O design deve aproveitar esse tema, funcionar em janelas redimensionáveis e comunicar bloqueio sem depender somente de opacidade ou cor.

## Goals / Non-Goals

**Goals:**

- Integrar Operações ao padrão de navegação e preservação de estado já existente.
- Criar uma superfície visual consistente, responsiva e acessível para as cinco operações.
- Manter os dados dos cards centralizados e fáceis de habilitar em incrementos futuros.
- Abrir Inspeção como uma rota filha convencional com retorno nativo previsível.
- Cobrir renderização, interação, bloqueio e adaptação de largura por testes de widget.

**Non-Goals:**

- Implementar formulários, persistência ou regras de domínio da Inspeção.
- Implementar os fluxos de Pulverização, Irrigação, Colheita ou Análise de Solo.
- Adicionar roteador declarativo, pacote de ícones, fontes ou dependências externas.
- Reformular as telas Inventário, Fazenda ou Sobre.

## Decisions

### 1. Manter o `IndexedStack` e inserir Operações no índice 2

O shell passará a ter Inventário, Fazenda, Operações e Sobre nos índices 0 a 3. A regra de inicialização preguiçosa da Fazenda continuará vinculada ao índice 1. Isso preserva o estado dos destinos e limita a mudança à arquitetura existente.

Alternativa considerada: migrar todo o app para um roteador declarativo. Rejeitada porque aumentaria o escopo sem benefício para uma única rota filha.

### 2. Organizar a nova feature em apresentação autocontida

A implementação ficará sob `lib/features/operations/presentation/`, com uma `OperationsView`, um card reutilizável e uma `InspectionView`. Uma lista imutável de descritores de apresentação concentrará título, ícone, cor semântica e disponibilidade; não haverá ViewModel enquanto não existir estado ou regra de domínio.

Alternativa considerada: codificar cinco cards individualmente na árvore de widgets. Rejeitada por duplicar marcação e tornar futuras liberações inconsistentes.

### 3. Usar uma grade guiada pelo espaço disponível

A tela usará `LayoutBuilder` e uma grade com `SliverGridDelegateWithMaxCrossAxisExtent`, mantendo cards com largura confortável e aumentando naturalmente o número de colunas. O conteúdo será centralizado e limitado a uma largura máxima em telas grandes, com rolagem vertical e padding seguro; decisões não serão baseadas em tipo de aparelho nem orientação.

Alternativa considerada: uma coluna fixa de cards. Rejeitada porque desperdiça espaço em tablets e janelas largas.

### 4. Aplicar uma linguagem visual agrícola baseada no tema Material 3

A tela terá título, breve texto introdutório e cards com ícone Material dentro de uma superfície tonal, nome em destaque e indicação de estado. A paleta deriva do `ColorScheme` existente: verde primário para Inspeção, tons secundários/terciários moderados para identificação das demais categorias e cores `onSurfaceVariant`/`outlineVariant` para estados bloqueados. Ícones previstos: inspeção (`fact_check_outlined`), pulverização (`pest_control_outlined` ou equivalente Material disponível), irrigação (`water_drop_outlined`), colheita (`agriculture_outlined`) e análise de solo (`science_outlined`). O destino Operações usará um par consistente de ícones contornado/preenchido.

Os cards terão alvo de toque de pelo menos 48 dp, borda visível, contraste textual compatível com o tema e feedback Material apenas quando habilitados. Nenhum emoji ou ativo remoto será usado.

Alternativa considerada: ilustrações ou pacote externo de ícones. Rejeitada para manter o APK e a identidade visual simples, consistente e offline.

### 5. Representar bloqueio como estado funcional e acessível

Cards indisponíveis terão callback nulo, ícone de cadeado e texto “Em breve”, além de `Semantics` informando que o controle está desabilitado. A cor terá papel secundário; o usuário não dependerá dela para compreender o estado. Tocar nesses cards não mostrará snackbar nem iniciará navegação.

Alternativa considerada: permitir o toque e mostrar aviso. Rejeitada porque aparenta interatividade e acrescenta ruído para uma ação que não pode ser concluída.

### 6. Abrir Inspeção com `Navigator.push`

O card habilitado abrirá uma `MaterialPageRoute` para uma `InspectionView` com `Scaffold`, `AppBar` intitulada “Inspeção” e retorno padrão. O corpo será uma base visual simples e não prometerá funcionalidades de domínio ainda não especificadas. Ao retornar, o `IndexedStack` preservará Operações como destino selecionado.

Alternativa considerada: trocar o conteúdo dentro do próprio destino e manter a barra inferior visível. Rejeitada porque o pedido descreve uma nova tela e a pilha padrão oferece retorno mais previsível.

### 7. Verificar comportamento com testes de widget e análise estática

Os testes do shell serão atualizados para a ordem dos quatro destinos. Testes dedicados validarão os cinco nomes, indicadores “Em breve”, ausência de navegação nos quatro cards bloqueados, abertura/retorno de Inspeção, semântica desabilitada e ausência de overflow em larguras compacta e ampla. Ao final, serão executados formatação, `flutter analyze` e a suíte de testes relevante.

## Risks / Trade-offs

- [Quatro destinos com rótulos longos podem ficar densos em telas muito estreitas] → Usar os padrões compactos da `NavigationBar`, ícones claros e validar em largura de 320 dp sem alterar os rótulos solicitados.
- [Cores distintas podem sugerir que cards bloqueados estão ativos] → Reduzir ênfase da superfície e combinar obrigatoriamente cadeado, texto “Em breve” e semântica desabilitada.
- [Uma tela de Inspeção sem domínio implementado pode parecer incompleta] → Manter uma composição intencional e mínima, sem ações falsas, deixando explícito apenas o contexto da área.
- [Mudança de índices pode quebrar testes ou lógica da Fazenda] → Usar constantes ou uma enumeração interna para os destinos e testar que Fazenda permanece no índice lógico correto.
- [Um ícone Material planejado pode não existir na versão atual do SDK] → Confirmar os símbolos durante a implementação e escolher o equivalente Material mais próximo sem adicionar dependência.

## Migration Plan

1. Adicionar a feature Operações e seus testes isolados.
2. Integrar o novo destino ao shell e ajustar índices/testes existentes.
3. Executar formatação, análise estática e testes de widget.
4. Em rollback, remover o quarto destino e a feature nova; não há dados, migração de banco ou contrato externo a reverter.
