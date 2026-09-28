## Context

Ver `proposal.md` para motivacao. Esta analise e estatica: nao foram coletados logs de um episodio, executados benchmarks ou comprovada uma causa raiz. O aviso de esperar/fechar sugere ANR; crash Dart, crash nativo, encerramento por memoria e overlay de carregamento sao hipoteses distintas.

Evidencias no codigo:

| Local | Observacao | Implicacao a medir |
| --- | --- | --- |
| `lib/core/data/shared_read_repository.dart` | Leitura local integral acontece antes de `_singleFlight`; apos gravar ocorre nova leitura integral | Consumidores podem repetir hidratacao e alocacoes |
| `lib/features/operations/data/inspection_local_store.dart` | `readSharedPlantRows` consulta tudo e decodifica JSON em loop; refresh monta mapas remoto, anterior e efetivo | CPU no isolate principal e pico de memoria |
| `lib/features/farm/data/supabase_plants_repository.dart` | Ja usa `compute` para DTOs, depois da leitura/decodificacao local | Otimizacao existente nao cobre o pipeline inteiro |
| `lib/features/farm/presentation/farm_map_view.dart` | Cria um Marker por planta antes do clustering nativo; assinatura usa quantidade, zona e icones | Clustering atual nao limita objetos enviados; mesma quantidade pode manter marcadores obsoletos |
| `lib/features/operations/presentation/inspection_view.dart` | Filtra/materializa plantas e cria todos os marcadores; assinatura tambem usa quantidade | Custo repetido e invalidacao insuficiente |
| `lib/features/operations/presentation/inspection_view_model.dart` | Getter filtra listas; varias mutacoes releem snapshot completo | Trabalho cresce com N mesmo para pequenas alteracoes |
| `lib/app/widgets/main_shell.dart` | IndexedStack preserva mapas; overlay AbsorbPointer global; pausa GPS apenas da Inspecao ao trocar aba | Mapas retidos e bloqueio perceptivel durante rede |
| `lib/features/farm/presentation/farm_map_view_model.dart` | GPS chama notifyListeners e so cancela em dispose | Tela oculta pode continuar reconstruindo |
| `lib/core/di/app_dependencies.dart` | Inventario recebe repositorios remotos, apesar dos construtores fromShared existentes | Divergencia de local-read-cache e requisicoes repetidas |
| `lib/features/inventory/presentation/inventory_view_model.dart` | Future.wait para todas as regioes | Concorrencia cresce com quantidade de zonas |
| `lib/features/operations/data/inspection_remote_data_source.dart` | Ocorrencias grandes paginadas sem ordenacao explicita | Risco de completude separado do desempenho |

## Goals / Non-Goals

**Goals:** limitar CPU, copias, objetos nativos e concorrencia; preservar estado funcional e dados offline; medir custos Dart e Android separadamente; usar arquitetura e repositorios existentes.

**Non-Goals:** reescrever app, alterar autorizacao/RLS, criar RPCs, alterar regras agronomicas ou sincronizacao de dominio, carregar dados reais de producao para testes, prometer ausencia universal de crash. O baseline Android fisico e obrigatorio para aceitar desempenho, mas nao para concluir esta proposta.

## Decisions

### 1. Medir antes de atribuir causa

Adicionar spans para abertura do banco, consulta local, decode, projecao/filtro, ocorrencias, persistencia, publicacao e envio de marcadores. Capturar FlutterError/erros assincronos preservando handlers anteriores e reporte padrao; nao engolir falhas. Usar buffer local limitado a 200 eventos sem payloads, com exportacao de diagnostico sob acao explicita. ANR/OOM nativo exige logcat/bugreport, motivo de saida quando suportado e PSS; excecoes Dart nao bastam.

Criar fixtures deterministicas 0/1k/21k/50k com distribuicao espacial dispersa, densa e pontos coincidentes, varias zonas, plantas nao existentes, coordenadas invalidas e fila pendente. Executar os ciclos e limites definidos em runtime-stability em aparelho fisico; salvar baseline e resultado. Nao adotar aumento de heap ou atualizacao indiscriminada de pacotes como correcao.

### 2. Um snapshot publicado e trabalho pesado fora da UI

Estender SharedReadRepository para compartilhar tambem hidratacao local, identificada por projeto e revisao monotona. Cachear projecoes imutaveis/indices por ID, zona e ocorrencia; liberar revisoes anteriores sem consumidores. A fila SQLite continua sendo fonte duravel de alteracoes locais. Publicar uma nova revisao somente apos commit, inclusive em edicoes/sync local que alterem estado. Consumidores ocultos recebem apenas invalidacao e derivam sua projecao quando ativados.

Executar decode/encode, montagem de indices e agrupamento em worker Dart com dados transferiveis simples; usar lotes iniciais de 500 registros e backpressure. Manter chamadas de plugins/banco sob o proprietario atual, salvo suporte comprovado do plugin ao isolate; nunca transportar Database, controller, widget ou dart:ui ao worker. Medir o custo da transferencia e evitar copiar o snapshot completo a cada GPS/viewport. Notificacoes locais devem transportar IDs/revisao para atualizar pequenas mudancas.

Alternativa de somente adicionar `async` nao desloca CPU; somente ampliar `compute` em cada consumidor duplica hidratacao e transferencias. Um worker reutilizavel e justificado pelo indice espacial e processamento recorrente, com encerramento no dispose.

### 3. Atualizacao em staging e publicacao curta

Persistir paginas remotas em staging separado do cache ativo, sem acumular todas as paginas em listas adicionais. Usar no maximo duas leituras remotas simultaneas, paginas de plantas de ate 1.000 e lotes locais de 500. Validar IDs, coordenadas para representacao e completude; nenhuma pagina curta causada por limite de servidor pode ser interpretada como exaustao sem verificar o contrato de paginacao. Garantir ordenacao deterministica de plantas e ocorrencias com chave unica real confirmada na implementacao; nao presumir que pares de ocorrencias sejam unicos. Manter o escopo de acesso atual.

Preparar nova geracao e seus totais/indices fora da transacao final; na publicacao serializar com gravacoes locais, aplicar mudancas pendentes mais recentes e trocar a revisao ativa atomicamente. Usar staging e metadados aditivos no SQLite, sem recriar tabelas de inspecao nem IDs da fila. Remover geracoes incompletas na recuperacao; leitor segue usando a anterior. Alteracoes confirmadas durante staging entram na publicacao final. Falha de disco preserva cache/filas existentes.

Leituras HTTP terao deadline de 30 segundos por requisicao; nao limitar a carga inteira a 30 segundos. Timeout invalida a geracao, libera estado de loading e impede commit tardio. Future.timeout sozinho nao cancela efeitos: verificar token antes de cada persistencia/publicacao, cancelar transporte se suportado e limitar operacoes pendentes. Repeticao explicita, sem loop de retry automatico. Nao modificar o contrato de idempotencia de sincronizacao de escrita.

Alternativa de grandes lotes dentro de uma unica transacao longa reduz chamadas, mas pode bloquear leitores e ampliar memoria. Staging torna recuperacao e leitura anterior explicitas.

### 4. Mapas proporcionais a viewport

Manter google_maps_flutter e substituir alimentacao de todos os pontos por projecao espacial limitada antes da ponte nativa. Avaliar biblioteca de indice/clustering mantida e compativel com pubspec.lock; validar prototipo contra o teto de 1.000 objetos. Construir indice por revisao no worker; consultar bounding box com pequena margem, zoom e filtros. Coalescer onCameraIdle com debounce inicial de 150 ms e descartar respostas de cameras anteriores.

Gerar clusters com contagem sobre todos os candidatos e refinar em zoom alto. Se ainda exceder o teto, manter agrupamento, nunca truncar a lista. Pontos coincidentes no zoom maximo abrem lista de membros paginada (50 por pagina) que permite selecionar qualquer planta, inclusive na Inspecao. A selecao entra no orcamento de objetos. Coordenadas invalidas ficam fora do mapa, mas permanecem nos dados e totais pertinentes.

Identificar resultado por revisao, filtros, viewport/zoom e estado dos icones; usar IDs estaveis. Atualizacao pequena altera apenas os objetos afetados. GPS possui notificacao separada da camada de plantas. Bounds iniciais por revisao/filtro sao precomputados; nao rematerializar todas as coordenadas em cada build. Liberar Picture/Image usados nos icones apos gerar bytes.

Alternativa de confiar apenas em ClusterManager atual mantem N marcadores Dart e transferencia nativa. Remover plantas acima de um limite viola completude e nao e aceitavel.

### 5. Ciclo de vida explicito sem perder dominio

MainShell coordena destino visivel, rota de Operacoes e lifecycle do app. Preservar ViewModels, rota, filtros, selecao e camera como dados, mas desmontar a superficie nativa dos mapas inativos. Apos transicao, no maximo um GoogleMap montado; em background, nenhum. Desativar stream GPS quando rota nao necessita dele ou app nao esta em foreground; retomar idempotentemente. Nao iniciar GPS apenas por selecionar menu Operacoes.

Usar geracoes/cancelamento de leituras de tela, guardas de dispose/mounted e validacao de identidade do controller antes/depois de awaits. A operacao compartilhada de carga pode continuar ao trocar aba; consumidores deixam de renderizar. Em background, suspender agendamento de novos lotes; ao encerrar processo, recuperar ultima revisao completa. Gravacoes locais ja iniciadas concluem sua transacao; nunca cancelar uma confirmacao no meio.

Alternativa de descartar toda a arvore/estado perde a rota da Inspecao. Somente Offstage/TickerMode nao comprova liberacao do mapa nativo.

### 6. Estado local de progresso e Inventario consistente

Retirar overlay global de leituras/refresh; expor etapa, progresso quando conhecido, erro e retry junto a operacao. Desabilitar somente comandos conflitantes, mantendo navegacao e snapshot anterior. Evitar percentuais inventados sem total conhecido.

Injetar os repositorios compartilhados no Inventario. Ler totais persistidos na mesma revisao (incluindo zonas/regioes quando disponiveis), sem carregar todas as plantas apenas para contar; invalidar apos publicacao. Primeira instalacao pode iniciar carga compartilhada completa, mantendo shell responsivo; reabertura nao gera GET adicional. O delta de inventory-dashboard resolve a antiga regra de reconsulta, alinhando-a a local-read-cache. Preservar dados cadastrais por tenant e comportamento geografico existente.

## Risks / Trade-offs

- [Reconstruir mapa custa tempo e tiles] -> preservar camera e dados, medir transicoes e nao depender de tiles para liberar navegacao.
- [Isolate pode duplicar memoria] -> transferir lotes e IDs, reutilizar indice e medir PSS, nao apenas heap Dart.
- [Staging usa espaco temporario] -> limpar apenas geracoes nao publicadas, reportar falta de espaco e nunca limpar fila para recuperar cache.
- [Mudanca local durante refresh] -> serializacao curta na publicacao e testes de interleaving/encerramento.
- [50.000 plantas nao cobrem todos os aparelhos] -> registrar hardware de referencia e um segundo Android de menor memoria quando disponivel; nao declarar validacao sem dispositivo real.
- [Biblioteca de clustering incompativel] -> spike antes de integrar, fixar versao aprovada e verificar alcance individual de pontos coincidentes; evitar algoritmo espacial proprio sem necessidade demonstrada.
- [ANR estar no plugin nativo] -> baseline inclui traces Android; atualizar plugin somente com evidencia e teste isolado de regressao.

## Migration Plan

1. Registrar baseline e criar testes de integridade/fixtures antes de mudar pipeline.
2. Entregar lifecycle e loading local, depois hidratacao compartilhada, staging e totais; validar cada etapa.
3. Migrar SQLite v2 de forma aditiva e transacional, com fixture contendo cache e fila pending/error/syncing. Se houver dados invalidos, falhar de forma recuperavel sem apagar inspecoes.
4. Integrar projecao espacial em Fazenda e Inspecao e validar matriz completa em profile/release.
5. Liberar somente apos criterios passarem, com relatorio de resultados e limitacoes. Rollback de codigo deve permanecer compativel com a versao SQLite nova; nao instalar binario antigo que recuse downgrade. Preferir correcao forward e nunca restaurar backup sobre novas inspecoes.

## Open Questions

- Modelo/RAM/Android do aparelho do episodio e disponibilidade de logs historicos: registrar quando acessiveis; nao bloqueia fixtures ou desenho.
- Qual etapa domina CPU/PSS no baseline? Define a prioridade dentro do plano, nao altera os contratos.
- Valores finais de batch/debounce e biblioteca compativel: escolher no spike mantendo os limites normativos.

## References

- [Flutter: concurrency and isolates](https://docs.flutter.dev/perf/isolates): CPU pesada pode ser deslocada; UI permanece no isolate principal e transferencia tem custo.
- [Android: ANRs](https://developer.android.com/topic/performance/issues/anr): investigar bloqueio de responsividade com evidencias do sistema.
- [Flutter DevTools: Memory](https://docs.flutter.dev/tools/devtools/memory): acompanhar alocacoes e memoria durante ciclos reproduziveis.

Referencias consultadas durante o planejamento; metas numericas sao criterios propostos para este aplicativo, nao garantias dos SDKs.
