## 1. Domínio e acesso aos totais

- [x] 1.1 Criar os modelos imutáveis do resumo numérico e do perfil da propriedade com os valores definidos na especificação, verificando por testes unitários que todos os campos são expostos corretamente.
- [x] 1.2 Criar o contrato de dados do Inventário e o repositório Supabase que obtém contagens exatas de `plants` para `non_existent = false` e `non_existent = true` sem transferir as linhas, verificando com testes de repositório os filtros, os totais e o resultado zero.
- [x] 1.3 Validar as consultas de contagem no aplicativo com a publishable key configurada, verificando em execução que as duas categorias carregam seus valores sem uso de credencial privilegiada.

## 2. Componentes geográficos compartilhados

- [x] 2.1 Extrair da tela Fazenda a construção e o estilo dos polígonos da propriedade e da zona para um helper compartilhado, verificando por testes que IDs, cores, preenchimentos, espessuras e ordem visual permanecem equivalentes.
- [x] 2.2 Extrair ou criar um cálculo reutilizável de câmera para limites geográficos, verificando por testes os casos com múltiplos pontos, um ponto e nenhum ponto.
- [x] 2.3 Implementar o carregamento geográfico do Inventário com `FarmRepository` e `ZonesRepository`, localizando a Zona A primeiro pelo código `A` e depois pelo nome normalizado, verificando por testes sucesso completo, um polígono disponível, ausência da zona e falha de consulta.

## 3. Estado do Inventário

- [x] 3.1 Implementar `InventoryViewModel` com cargas paralelas e estados independentes para totais e mapa, verificando por testes transições de carregamento, sucesso, zero, erro integral e sucesso parcial.
- [x] 3.2 Implementar novas tentativas independentes e idempotentes para totais e geografia, verificando por testes que cada ação atualiza somente o bloco correspondente e busca dados atuais.
- [x] 3.3 Garantir descarte seguro e prevenção de atualizações após o fim do ciclo de vida, verificando por teste que respostas assíncronas tardias não geram notificações inválidas.

## 4. Interface visual do painel

- [x] 4.1 Substituir a tela vazia por um painel rolável com fundo, espaçamento, bordas, sombras, raios e tipografia definidos no design, verificando em teste de widget a ordem semântica dos quatro blocos.
- [x] 4.2 Implementar o hero com “Sítio São Francisco”, “54 ha”, chip “Avocado” e `assets/images/avocado.png` usando `BoxFit.contain`, limite responsivo, semântica e fallback, verificando os estados normal e de falha do asset em teste de widget.
- [x] 4.3 Implementar os cards “Plantas existentes” e “Disponíveis para plantio” com formatação de milhares, ícones Material e estados de loading/zero/erro/retry, verificando por testes de widget rótulos, valores e ações.
- [x] 4.4 Implementar o card “Configuração do cultivo” com Espaçamento, Classificação, Adensamento e Variedade, verificando que os valores exatos da especificação permanecem associados aos respectivos rótulos com escala de texto ampliada.
- [x] 4.5 Implementar o card de mapa com legenda acessível, polígonos da fazenda e Zona A, câmera enquadrada e conjuntos vazios de marcadores/clusters, verificando por teste que nenhuma planta é solicitada ou renderizada.
- [x] 4.6 Adaptar hero, indicadores, detalhes e mapa para 320 px e larguras maiores usando composição responsiva, verificando por testes de widget em múltiplos tamanhos e escala de texto que não há overflow nem rolagem horizontal.

## 5. Integração e regressão

- [x] 5.1 Compor o repositório e o `InventoryViewModel` no bootstrap/shell, inicializando-os somente para o ciclo de vida do destino Inventário, verificando que o primeiro destino carrega o painel e que a navegação inferior continua preservando seu estado.
- [x] 5.2 Atualizar os testes da tela Fazenda após a extração geográfica, verificando que seleção de zona, polígonos, marcadores, clustering e localização continuam com o comportamento anterior.
- [x] 5.3 Exercitar falhas independentes do Supabase e ausência de coordenadas, verificando que o conteúdo estático e o bloco bem-sucedido permanecem disponíveis e que “Tentar novamente” recupera cada seção.

## 6. Qualidade final

- [x] 6.1 Executar o formatador, a análise estática e toda a suíte Flutter, corrigindo qualquer falha até que a formatação de `lib` e `test`, `dart analyze` e `flutter test` concluam com sucesso.
- [x] 6.2 Validar visualmente no emulador Android e por renderização de widget nos perfis Android/iOS a hierarquia, contraste, sombras, proporção da ilustração, gestos do mapa e adaptação entre 320 px e telas amplas, confirmando que não há conteúdo encoberto pela navegação inferior.
