# Padrões visuais e comportamentais

Consulte o código canônico antes de implementar. Os números abaixo documentam o estado atual e ajudam a detectar divergências; o código prevalece se evoluir.

## Mapa e localização do dispositivo

Fontes canônicas:

- `lib/features/operations/presentation/spraying_view.dart`
- `lib/features/operations/presentation/spraying_view_model.dart`
- `lib/features/operations/domain/spraying_location_filter.dart`
- `lib/features/operations/presentation/spraying_map_camera.dart`
- `lib/features/operations/presentation/spraying_heading.dart`
- `lib/features/farm/presentation/user_map_navigation.dart`
- `lib/core/ui/map_activity.dart`

Reproduza o conjunto inteiro, não apenas o `GoogleMap`:

- `MapType.satellite`;
- posição de fallback `defaultFarmMapPosition`, zoom `17` quando ainda não existe uma posição válida;
- foco inicial no usuário com zoom `19` no uso normal;
- início da gravação com zoom `18.5` (`_recordingStartZoom`);
- botão de app bar `Icons.my_location` para recentralizar;
- `myLocationEnabled`, `myLocationButtonEnabled`, controles de zoom e toolbar desativados;
- marcador criado por `createUserLocationMarkerIcon()`: círculo branco externo, círculo azul `0xFF1976D2`, brilho `0xFF90CAF9`, bitmap visual de 28 x 28, âncora central e prioridade alta;
- obtenção contínua por `LocationService.watchLocation()` e filtro `SprayingLocationFilter` antes de publicar posição;
- sem modal ou loading para “estabilizar o sinal”. Amostras inválidas ou outliers são descartados silenciosamente enquanto o stream continua;
- durante acompanhamento ativo, mantenha o usuário dentro da área útil com `isInsideSprayingFocusArea`, `sprayingFollowCameraPosition` e o curso calculado. Preserve margem relativa atual de 12%, fila de atualização e limitação de animações para evitar tremulação;
- respeite `ActiveMapSurface`: iniciar localização quando a superfície ficar ativa e cancelar stream/soltar controller quando ficar inativa;
- salve a câmera em `onCameraMove`, atualize clusters em `onCameraIdle` e preserve interação manual sem brigar continuamente com o usuário fora do modo que exige acompanhamento;
- ao desenhar rota, use a posição aceita pelo filtro, distância mínima e precisão máxima definidas no domínio/ViewModel, nunca a amostra bruta diretamente.

Prefira reutilizar `UserMapNavigator`, `createUserLocationMarkerIcon` e os helpers compartilhados. Se a nova funcionalidade exigir exatamente a política de Pulverização, extraia a configuração/coordenação para uma abstração compartilhada em vez de copiar os campos privados da View.

## Ações abaixo do mapa

Fonte canônica: `lib/features/operations/presentation/widgets/spraying_action_card.dart`.

O bloco fica imediatamente abaixo do mapa, dentro de `SafeArea(top: false)`, com margem horizontal 16, vertical 8 e largura máxima 480. A superfície usa:

- fundo `colorScheme.surface`;
- raio externo 24;
- borda `outlineVariant` com alpha 0,6;
- sombra preta leve, blur 14 e deslocamento vertical 4;
- padding interno horizontal 12 e vertical 10.

Cada ação compacta usa somente ícone, `Tooltip` e semântica acessível. O alvo tem altura 52, raio 16, borda 1,5 e cores semânticas próprias. Badge comunica filtro, gravação, pausa ou contagem sem substituir o tooltip.

Para novas telas, disponha as ações em `Wrap` ou em layout calculado com `LayoutBuilder`: alinhamento horizontal, espaçamento 10 e quebra para a linha seguinte quando a largura não comportar todos os alvos. Nunca comprima ícones abaixo de um alvo de toque confortável e nunca cause overflow. Teste ao menos largura de 320 px e escala de texto aumentada.

Funcionalidade equivalente deve reutilizar o mesmo componente de botão e a mesma combinação de ícone/cor/estado. Caso `_ActionButton` ainda seja privado, promova-o a componente compartilhado configurável antes de duplicá-lo.

## Modal de filtros

Fonte canônica: `lib/features/operations/presentation/widgets/spraying_zone_filter_modal.dart` (`Filtros de Plantas`).

Use `showModalBottomSheet`, `isScrollControlled: true` e fundo transparente. A folha tem superfície do tema, raio superior 24 e clipping. A altura atual é 78% da tela, limitada entre 520 e 780 px; mantenha a mesma distância percebida do topo e valide telas menores com constraints seguras.

Estrutura obrigatória:

1. Cabeçalho fixo com padding `(20, 14, 12, 8)`.
2. Ícone `Icons.tune_rounded`, tamanho 24 e cor primária.
3. Espaço 10, título `titleLarge` em negrito, subtítulo `bodySmall` em `outline`.
4. Ação `Limpar` somente quando houver filtro e botão de fechar à direita com tooltip.
5. `Divider(height: 1)`.
6. Conteúdo com padding horizontal 20; labels `labelLarge` em negrito e distância 6 até o campo.
7. Rodapé fixo com ação principal, padding `(20, 8, 20, 16)`, altura confortável e raio 14.

Campos seguem o padrão preenchido: `surfaceContainerHighest` com alpha 0,35; raio 14; borda `outlineVariant`; foco primário com largura 2; ícone prefixado coerente. Filtros de plantas ou de qualquer outra entidade devem usar esse mesmo esqueleto, alterando apenas ícone, textos, opções e regra de filtro.

## Coleta curta e detalhes

Fonte canônica: `lib/features/operations/presentation/widgets/spraying_session_modal.dart` (`Controle de Pulverização`).

Use bottom sheet que sobe da base para ações com pouca coleta ou poucos detalhes. Altura máxima atual: 75% da tela. Mantenha:

- fundo transparente no route e `Material` com raio superior 24;
- drag handle 36 x 4, margem superior 10 e inferior 4;
- cabeçalho com padding `(20, 8, 12, 12)`;
- ícone em contêiner com padding 8, raio 10 e `primaryContainer` alpha 0,5;
- título de 20 px/negrito, subtítulo contextual e fechar à direita;
- divisor e conteúdo com padding horizontal 20;
- cartões informativos com raio 14, borda `outlineVariant` e preenchimento tonal;
- ações principais com padding vertical 14 e raio 14.

Use `SafeArea(top: false)` e conteúdo rolável quando o tamanho ou a acessibilidade puderem exceder a altura. Fechar o modal não pode perder dados já persistidos nem deixar operação assíncrona sem tratamento.

## Formulários e seletores

Fontes canônicas:

- `lib/features/operations/presentation/widgets/spraying_registration_modal.dart`
- `lib/features/operations/presentation/widgets/spraying_review_modal.dart`
- `lib/features/operations/presentation/widgets/activity_catalog_components.dart`

Reutilize o cabeçalho e a altura de 75%. Com teclado, anime o padding inferior usando `MediaQuery.viewInsetsOf(context).bottom` e mantenha o rodapé de salvar acessível.

Padrão dos inputs:

- label `labelLarge` em negrito e espaço inferior 6;
- preenchimento tonal com alpha 0,35;
- content padding horizontal 14 e vertical 12;
- raio 14 em todos os estados;
- borda normal `outlineVariant`;
- foco primário, largura 2;
- erro com `colorScheme.error`, largura 2 quando focado;
- `prefixIcon` que descreva o campo;
- validação no formulário e mensagens junto ao campo;
- botão principal no rodapé com altura mínima 50.

Seletores de catálogos abrem outro bottom sheet, apresentam pesquisa e itens consistentes, mas o campo de pesquisa não deve ter `autofocus` nem receber `requestFocus()` ao abrir. O teclado só aparece após ação explícita do usuário.

Use o mesmo tratamento para dropdowns e toggles: fundo tonal, raio 14, estados de foco/erro do tema, label clara e área de toque acessível. Não crie um segundo dialeto visual para um tipo de controle ainda não presente; componha-o a partir desses tokens.

## Listas salvas localmente

Fonte canônica: `lib/features/operations/presentation/widgets/local_sprayings_modal.dart`.

O modal usa a mesma base de 75% e o mesmo drag handle. O header deve permanecer idêntico em estrutura:

- ícone/logomarca em contêiner tonal 38 x 38 aproximadamente;
- título `titleLarge`, 20 px e negrito;
- subtítulo com quantidade de registros no dispositivo;
- fechar no extremo direito;
- padding `(20, 8, 12, 12)` e divisor.

O card salvo usa raio 18, barra de status colorida de 5 px à esquerda, fundo levemente tingido pelo status, borda e sombra da mesma família cromática. Preserve:

- identidade no topo com ícone, título e data sem qualquer sobreposição;
- status não sincronizado abaixo do título/data;
- detalhes em painel interno de raio 14;
- métricas em tiles de raio 12;
- divisor antes das ações;
- rascunho: excluir à esquerda e `Revisar` à direita, na mesma linha;
- sincronizado: excluir à esquerda e badge `Sincronizada` no final à direita;
- revisado/erro: ações responsivas em `Wrap`, mantendo exclusão, revisão e sincronização discerníveis;
- status por cor, ícone e texto — nunca somente por cor.

Paleta semântica atual: sincronizado verde `0xFF15803D`, sincronizando azul-claro `0xFF0284C7`, pronto para envio azul `0xFF2563EB`, erro vermelho `0xFFC62828`, aguardando revisão âmbar `0xFFD97706`.

Para outra entidade salva, mantenha estrutura, tokens, estados, header, vazio, feedback e rodapé. Troque somente rótulos, ícone da entidade, métricas e callbacks. Extraia componentes compartilhados quando a nova lista for implementada.

## Verificação visual mínima

- 320 px de largura, largura usual de telefone e tablet;
- texto padrão e texto ampliado;
- lista vazia, um item e muitos itens;
- todos os estados de status e ações desabilitadas/carregando;
- teclado aberto em formulário;
- mapa sem permissão, sem localização, com localização válida e com usuário saindo da área útil;
- tema configurado pelo app, sem cores pretas/cinzas dominando informações que possuem semântica própria.
