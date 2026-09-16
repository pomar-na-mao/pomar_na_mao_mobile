## Context

A tela Sobre já existe como `AboutView`, mas atualmente não apresenta conteúdo funcional. A navegação inferior e o tema Material 3 já estão configurados no app, então a mudança deve ficar concentrada na feature `about` e reaproveitar o `ColorScheme` existente.

## Goals / Non-Goals

**Goals:**
- Criar uma tela Sobre visualmente agradável, legível e compatível com diferentes tamanhos de tela.
- Exibir duas seções institucionais claras: Pomar na mão e Prímora.
- Manter a implementação simples e local, sem dependência de rede ou novas bibliotecas.

**Non-Goals:**
- Não adicionar CMS, Supabase ou configuração remota para o conteúdo institucional.
- Não alterar a navegação inferior nem os destinos existentes.
- Não implementar formulários, links externos ou páginas adicionais.

## Decisions

- Implementar o layout diretamente em `AboutView`, pois o conteúdo é estático e não exige ViewModel neste momento. Alternativa considerada: criar uma ViewModel para textos institucionais; isso adicionaria abstração sem ganho prático para conteúdo fixo.
- Usar `SingleChildScrollView` com padding seguro para garantir leitura em telas pequenas. Alternativa considerada: layout fixo sem rolagem; isso poderia cortar texto em aparelhos menores ou com fonte ampliada.
- Usar componentes Material como `Card`, `Icon`, `Text` e cores derivadas do `ColorScheme` para manter consistência visual com o restante do app. Alternativa considerada: assets gráficos próprios; não são necessários para esta versão e poderiam aumentar o escopo.
- Separar visualmente Pomar na mão e Prímora em blocos próprios para tornar o papel de cada organização claro.

## Risks / Trade-offs

- Texto estático pode exigir nova publicação do app para alterações futuras -> manter os textos centralizados na View para facilitar manutenção.
- Cards com conteúdo institucional podem ficar extensos em telas pequenas -> usar rolagem e espaçamentos compactos.
- A identidade visual final pode evoluir com branding oficial -> usar tema e ícones simples para permitir troca posterior sem reestruturar a tela.
