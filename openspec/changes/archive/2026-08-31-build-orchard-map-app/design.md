## Context

O repositório contém o projeto Flutter inicial, com `lib/main.dart` e alvos gerados para várias plataformas, mas sem arquitetura ou integrações de domínio. Esta mudança introduz navegação, acesso remoto, mapa nativo e localização; consulte `proposal.md` para a motivação e `specs/` para o comportamento esperado.

A primeira entrega será suportada em Android e iOS. A tabela `public.plants` já existe no projeto Supabase `uxschjkypkkzprbwuhxm`; o cliente precisa apenas de leitura dos registros. A chave Supabase fornecida é publicável, portanto a segurança dos dados depende de Row Level Security e de uma política `SELECT` compatível. A chave Google Maps ficará incorporada aos aplicativos móveis por exigência dos SDKs e deverá ser restringida por package name/SHA no Android e bundle identifier no iOS.

## Goals / Non-Goals

**Goals:**

- Estabelecer uma estrutura MVVM simples, explícita e extensível, alinhada à orientação de arquitetura do Flutter.
- Manter widgets focados em renderização e eventos, concentrando estado de apresentação e coordenação no ViewModel.
- Isolar Supabase e localização atrás de repositórios/serviços injetáveis por construtor.
- Representar carregamento, sucesso, vazio e falha sem remover a usabilidade básica do mapa.
- Evitar armazenar credenciais privilegiadas; usar somente a chave publicável do Supabase e uma chave Google Maps restrita.

**Non-Goals:**

- Implementar conteúdo funcional de Inventário ou Sobre.
- Criar, editar, remover, sincronizar em tempo real ou paginar plantas.
- Exibir detalhes completos, variedades ou zonas das plantas.
- Alterar a tabela `plants`, criar autenticação de usuário ou definir uma nova política de negócio de RLS.
- Suportar Google Maps em web, Windows, macOS ou Linux nesta entrega.
- Adicionar testes unitários, de widget ou de integração nesta mudança.

## Decisions

### Organizar por funcionalidades com camadas MVVM

O código será dividido em `lib/app/` para composição e shell, `lib/features/<feature>/presentation/` para Views e ViewModels, `lib/features/<feature>/domain/` para modelos e contratos e `lib/features/<feature>/data/` para implementações de acesso externo. Dependências compartilhadas e configuração ficarão em `lib/core/`.

Views observarão ViewModels baseados em `ChangeNotifier`, criados com dependências por construtor. Essa abordagem aplica MVVM sem introduzir um framework adicional de estado para apenas três telas. Alternativas consideradas: Provider/Riverpod, que agregariam conveniência de injeção mas aumentariam a superfície inicial; e lógica diretamente nos widgets, rejeitada por misturar apresentação, rede e localização.

### Usar um shell único com `NavigationBar` e `IndexedStack`

O shell manterá o índice selecionado e exibirá Inventário, Fazenda e Sobre em um `IndexedStack`. Isso preserva a instância e o estado do mapa ao alternar abas e evita recarregar plantas ou recriar o controlador do Google Maps a cada toque.

A alternativa de rotas nomeadas para cada aba foi descartada por adicionar complexidade de navegação sem benefício nesta primeira versão. Rotas poderão ser introduzidas quando houver fluxos internos.

### Inicializar o Supabase antes de montar o aplicativo

O ponto de entrada carregará o Project URL `https://uxschjkypkkzprbwuhxm.supabase.co` e a publishable key por configuração de build, inicializará `Supabase`, criará as dependências e então montará o app. Valores poderão ter defaults de desenvolvimento documentados, mas nenhuma service-role key será aceita no cliente.

`PlantsRepository` consultará `public.plants` e mapeará cada linha para um modelo `Plant`, incluindo todos os campos do schema para preservar a fronteira de dados, embora o mapa use inicialmente `id`, `latitude` e `longitude`. A leitura será única ao iniciar o ViewModel, com nova tentativa explícita após falha. Realtime e paginação foram descartados porque não foram solicitados e poderiam mudar o comportamento e consumo de recursos.

Antes da implementação, a política RLS de leitura deverá ser verificada com o MCP Supabase. Se clientes públicos não tiverem permissão de `SELECT`, a implementação será considerada bloqueada até existir uma política aprovada; não será desabilitado RLS nem usada chave privilegiada como atalho.

### Coordenar mapa, plantas e localização em um ViewModel

`FarmMapViewModel` possuirá o estado de carregamento das plantas, mensagem de erro/vazio, coleção de plantas e estado de localização. Ele disparará a carga uma única vez e oferecerá uma ação de retry. Um serviço de localização encapsulará verificação do serviço, estado da permissão, solicitação de permissão e obtenção da posição.

A View converterá plantas em `Marker`s e habilitará a camada de localização somente quando autorizada. Após o mapa ficar pronto e os dados disponíveis, a câmera será ajustada: bounds quando houver múltiplas plantas, coordenada da única planta, posição do usuário se não houver plantas e uma região padrão da fazenda como último fallback. A região padrão será derivada das coordenadas existentes do projeto durante a implementação; na ausência delas, será usada uma coordenada documentada e facilmente substituível.

Uma alternativa seria deixar toda a coordenação no widget do mapa, mas isso dificultaria distinguir estados de domínio de callbacks específicos do SDK.

### Configurar integrações nativas por plataforma

Serão adicionadas as permissões de localização exigidas ao Android Manifest e ao iOS Info.plist, com texto de finalidade em português. A chave Google Maps será conectada ao Android Manifest e à inicialização iOS usando configuração local/de build ignorada pelo Git quando possível, acompanhada de arquivos-exemplo ou instruções no README. Como chaves de Maps são recuperáveis do binário, restrições no Google Cloud são obrigatórias mesmo quando o valor não está versionado.

Os pacotes previstos são `supabase_flutter`, `google_maps_flutter` e `geolocator`. As versões serão resolvidas para versões estáveis compatíveis com o SDK Flutter atual do projeto durante a implementação.

## Risks / Trade-offs

- [A política RLS impede leitura anônima/publicável de `plants`] → Verificar políticas antes de codificar o fluxo e exigir uma política `SELECT` mínima aprovada, sem usar service-role key.
- [A chave Google Maps fornecida pode estar irrestrita ou já exposta] → Restringir a chave no Google Cloud por aplicativo e APIs necessárias; recomendar rotação se ela não puder ser adequadamente restringida.
- [Muitos registros podem degradar a renderização de marcadores] → Manter a primeira versão simples e medir com dados reais; adotar clustering ou consulta por viewport em mudança futura se necessário.
- [Permissão negada permanentemente ou GPS desativado] → Tratar como estado recuperável, manter as plantas disponíveis e orientar o usuário sem bloquear o mapa.
- [O SDK do mapa falha sem configuração nativa válida] → Validar separadamente builds e execução em Android e iOS com a configuração documentada.
- [Uso de `IndexedStack` mantém o mapa em memória] → Aceitar o consumo em troca de preservar estado e evitar recriação; reconsiderar caso o perfil de memória indique problema.

## Migration Plan

1. Confirmar versões do Flutter/Dart e compatibilidade das dependências.
2. Verificar no Supabase a existência da tabela, colunas e política de leitura aplicável à publishable key.
3. Introduzir a estrutura MVVM, dependências e configuração sem remover arquivos nativos gerados necessários.
4. Configurar Android e iOS com permissões e chave Google Maps restrita.
5. Executar análise estática e validar manualmente navegação, estados do Supabase, marcadores e fluxos de permissão em Android e iOS.

Rollback: reverter as dependências, código em `lib/` e configurações nativas desta mudança. Nenhuma migração de banco está planejada, portanto não há rollback de dados.
