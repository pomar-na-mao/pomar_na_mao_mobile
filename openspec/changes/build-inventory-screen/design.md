## Context

Consulte `proposal.md` para a motivação e `specs/inventory-dashboard/spec.md` para o contrato observável. O destino Inventário já é a primeira página do `IndexedStack`, porém sua view contém apenas um `Scaffold` vazio. A feature Fazenda já possui repositórios Supabase para todas as plantas, zonas, regiões e pontos do limite da fazenda, além de um mapa com polígonos; sua apresentação e seus helpers são privados e também carregam localização e milhares de marcadores, responsabilidades que o Inventário não necessita.

O schema remoto confirma `plants.non_existent`, uma Zona A identificada por nome e código, e fontes geográficas já consumidas pelo app. Não existe uma entidade remota dedicada aos metadados da propriedade. Nesta entrega, os valores informados pelo usuário serão um perfil imutável e centralizado no cliente; migrar esses dados para persistência poderá ser uma mudança posterior sem alterar a composição visual.

O asset `assets/images/lichia.png` já está incluído pelo glob de assets do `pubspec.yaml`. O tema Material 3 usa a cor semente `#3C6E47`, e o Google Maps já está configurado para as plataformas suportadas.

## Goals / Non-Goals

**Goals:**

- Manter o carregamento inicial do Inventário leve, obtendo no servidor apenas contagens exatas em vez de transferir todos os registros de plantas.
- Separar estados dos indicadores e do mapa para preservar conteúdo útil quando uma fonte falhar.
- Reaproveitar contratos geográficos existentes e extrair apenas os elementos de estilo/câmera que realmente forem compartilhados.
- Entregar uma composição mobile-first legível a 320 px, que também aproveite larguras maiores.

**Non-Goals:**

- Cadastrar ou editar fazenda, cultivo, espaçamento, adensamento ou variedade.
- Alterar o schema Supabase, as políticas RLS ou os dados remotos.
- Exibir plantas, clusters, localização do usuário ou filtro de zonas no mapa do Inventário.
- Alterar o comportamento ou a aparência funcional da tela Fazenda.

## Decisions

### 1. Criar estado e repositório próprios para o Inventário

Será criado um `InventoryViewModel` com estados independentes para resumo numérico e mapa. Um contrato de repositório específico consultará duas contagens exatas em `public.plants`, filtradas por `non_existent`, sem baixar as aproximadamente 22 mil linhas hoje necessárias ao mapa Fazenda. O ViewModel usará também os contratos existentes `FarmRepository` e `ZonesRepository` para buscar o limite da fazenda, localizar a Zona A preferencialmente por `code == 'A'` (com fallback por nome normalizado) e carregar seus pontos.

Isso evita inicializar ou compartilhar o `FarmMapViewModel`, cujo ciclo de vida inclui localização, seleção de zona e marcadores. A alternativa de reutilizá-lo reduziria classes, mas acoplaria o primeiro destino do app a trabalho caro e a permissões não solicitadas.

As consultas dos totais e dos dados geográficos serão iniciadas em paralelo. Cada grupo manterá estado `initial/loading/success/error`, permitindo sucesso parcial e nova tentativa idempotente.

### 2. Manter o perfil da propriedade centralizado e tipado no cliente

Um modelo imutável de apresentação concentrará nome, área, cultivo, faixa de espaçamento, classificação, faixa de adensamento e variedade. A instância inicial conterá exatamente “Sítio São Francisco”, “54 ha”, “Avocado”, “7 × 7 m a 8 × 8 m”, “Semi-adensado”, “70 a 100 plantas/ha” e “Hass”.

Centralizar esses valores evita espalhar literais por widgets e facilita substituir a origem por configuração remota posteriormente. Criar uma tabela nova agora foi descartado porque o pedido não define edição, múltiplas propriedades, vínculo de usuário nem ciclo de vida desses dados.

### 3. Compor a tela como painel vertical em blocos

A view usará rolagem vertical e quatro áreas:

1. cabeçalho/hero da propriedade, com nome, área, chip de cultivo e a ilustração de avocado;
2. dois cards de indicadores, “Plantas existentes” e “Disponíveis para plantio”;
3. card “Configuração do cultivo”, com os quatro pares rótulo/valor;
4. card “Mapa da propriedade”, com legenda e mapa de altura limitada.

Em telas compactas, hero e detalhes se reorganizam verticalmente e os indicadores usam `Wrap` ou restrições que preservem a leitura com escala de texto elevada. Em larguras maiores, os blocos podem dividir a linha sem mudar a ordem semântica. A tela não usará alturas fixas para conteúdo textual; somente o viewport do mapa terá altura controlada.

O visual seguirá a linguagem Material 3 existente e as diretrizes do `ui-ux-pro-max`: fundo verde muito claro (`#F4F7F2`), superfícies brancas, verde principal alinhado ao tema (`#3C6E47`), verde escuro para texto de destaque, âmbar moderado no indicador de disponibilidade e bordas sutis. Cards terão raio entre 16 e 20 px, borda de baixo contraste e sombra curta com baixa opacidade; ícones serão todos Material, sem emojis. Cor nunca será o único diferenciador: rótulos, valores e legenda acompanharão cada tom.

A ilustração será renderizada com `BoxFit.contain`, limite de tamanho e fallback de erro neutro. O rótulo semântico “Avocado” será aplicado sem duplicar anúncio do texto próximo.

### 4. Extrair a representação compartilhada dos polígonos, não o mapa Fazenda inteiro

As cores e a construção dos polígonos serão movidas para um helper/widget reutilizável pela Fazenda e pelo Inventário: limite da fazenda em azul (`#1565C0`, preenchimento translúcido) e zona em verde (`#1B5E20`, preenchimento translúcido), preservando `strokeWidth`, geodesia e ordem visual atuais. A extração deverá ser coberta por teste para garantir que a Fazenda continue equivalente.

O mapa do Inventário criará somente esses polígonos e passará conjuntos vazios de marcadores/clusters. Não solicitará localização. A câmera calculará os limites da união dos pontos válidos da fazenda e da Zona A e aplicará padding; se houver apenas um ponto utilizável, usará zoom aproximado, e sem pontos usará a posição padrão existente. A legenda fora do canvas identificará ambos os polígonos e continuará acessível mesmo se uma área estiver indisponível.

Duplicar a implementação privada atual seria mais rápido, mas aumentaria o risco de divergência visual. Reusar a `FarmMapView` completa foi descartado porque ela necessariamente carrega e desenha plantas e expõe controles que violam o escopo.

### 5. Tratar falhas por bloco e preservar a estrutura durante carga

Os cards de contagem exibirão skeletons ou indicadores compactos enquanto aguardam resposta; o card do mapa manterá seu tamanho para evitar salto de layout. Uma falha nos totais não esconderá o perfil nem o mapa, e uma falha geográfica não esconderá os totais. Cada erro mostrará texto curto e ação “Tentar novamente”, acionando somente o grupo relevante.

Erros técnicos não serão exibidos diretamente. Um resultado vazio de contagem será zero; coordenadas insuficientes produzirão aviso não bloqueante, não uma exceção de tela inteira.

### 6. Formatar e testar sem nova dependência

Os totais serão formatados com separador de milhar para leitura em português por uma função local pequena ou utilitário já disponível, evitando adicionar uma dependência apenas para dois inteiros. Testes de repositório validarão os filtros booleanos e contagens; testes de ViewModel cobrirão sucesso, zero, falha parcial e retry; testes de widget verificarão conteúdo, adaptação a 320 px, escala de texto, semântica da imagem e ausência de overflow; testes do helper geográfico verificarão os dois polígonos e o conjunto vazio de plantas no Inventário.

## Risks / Trade-offs

- [Contagens separadas podem refletir instantes ligeiramente diferentes durante escrita concorrente] → Executar em paralelo e aceitar consistência eventual para um painel informativo; uma função SQL atômica pode ser adotada se consistência transacional se tornar requisito.
- [As políticas RLS podem permitir ler linhas, mas não retornar contagem exata] → Validar as consultas com a publishable key e apresentar erro recuperável sem usar credencial privilegiada.
- [Identificação textual da Zona A pode variar] → Priorizar o código estável `A`, usar nome normalizado apenas como fallback e tratar ausência como dado parcial.
- [Extração dos helpers do mapa pode introduzir regressão na tela Fazenda] → Preservar os valores visuais atuais e cobrir a criação dos polígonos e o fluxo Fazenda com testes existentes e novos.
- [Google Maps dentro de conteúdo rolável pode competir com o gesto vertical] → Limitar a altura, manter margem visual clara e validar gestos em Android/iOS; se necessário, restringir reconhecedores sem remover zoom/pan intencionais.
- [Perfil local pode ficar desatualizado] → Manter todos os valores em uma única estrutura injetável e documentar a futura troca por fonte persistida.

## Migration Plan

1. Adicionar os novos contratos, modelos, repositório de contagens e ViewModel sem alterar o destino Fazenda.
2. Extrair e testar os helpers compartilhados de polígonos/câmera, mantendo a renderização atual da Fazenda.
3. Conectar o ViewModel do Inventário no ponto de composição e substituir a view vazia pelo painel.
4. Executar análise estática, testes unitários/widget e validação manual em larguras compactas e amplas nas plataformas móveis.

O rollback consiste em restaurar a `InventoryView` vazia e remover a nova composição; não há migração de dados ou schema a reverter.
