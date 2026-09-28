## 1. Baseline e diagnostico

- [x] 1.1 Criar fixtures deterministicas de 0, 1.000, 21.000 e 50.000 plantas, incluindo zonas, ocorrencias, pontos coincidentes/invalidos e fila offline; verificar contagens e integridade em testes, sem usar producao.
- [x] 1.2 Instrumentar etapas de carga, mapas e lifecycle com buffer limitado e handlers encadeados; verificar teste de limite de eventos e ausencia de coordenadas, payloads e credenciais no diagnostico exportado.
- [x] 1.3 Registrar aparelho fisico, RAM, Android, build e plugins e executar baseline de navegacao, abertura, retomada e memoria; entregar relatorio com traces Flutter/Android e separar causas confirmadas de hipoteses.

## 2. Navegacao e lifecycle

- [x] 2.1 Substituir overlay global de leituras por progresso/erro no contexto da operacao; verificar teste de navegacao durante carga pendente, falha e refresh com cache anterior.
- [x] 2.2 Coordenar visibilidade de destino/rota e lifecycle, desmontando mapas inativos e preservando camera, filtros, selecao e rota de Inspecao; verificar no Android no maximo um mapa montado em foreground e nenhum apos suspensao.
- [x] 2.3 Tornar inicio/pausa de GPS idempotente em Fazenda e Inspecao; verificar subscriptions contadas em testes de aba, menu Operacoes, rota coberta e background/retomada.
- [x] 2.4 Proteger callbacks e controllers contra dispose e respostas obsoletas; verificar testes com futures fora de ordem e saida da tela antes de concluir carga/camera.

## 3. Hidratacao compartilhada

- [x] 3.1 Compartilhar leituras locais em andamento e snapshot por projeto/revisao em SharedReadRepository; verificar uma hidratacao por revisao para consumidores simultaneos, cache vazio conhecido e isolamento entre projetos.
- [x] 3.2 Introduzir worker para decode/encode e indices com lotes/backpressure; verificar equivalencia de dados e trace sem decode integral no isolate principal, medindo memoria de transferencia.
- [x] 3.3 Publicar revisao apos commits locais e refresh, atualizando projecoes por IDs e liberando revisoes antigas; verificar coordenadas/ocorrencias alteradas sem mudanca de quantidade e falta de recomputacao integral em eventos GPS.

## 4. Persistencia e carga limitada

- [x] 4.1 Adicionar staging e metadados de geracao/totais por migracao SQLite nao destrutiva; verificar upgrade a partir de v2 com inspecoes pending/error/syncing e reabertura sem perda de IDs ou alteracoes.
- [x] 4.2 Processar paginas remotas diretamente em staging e limitar concorrencia de referencias/regioes; verificar teto de duas leituras simultaneas, lotes limitados e carga completa acima de 21.000 registros sem listas integrais redundantes.
- [x] 4.3 Garantir paginacao deterministica de plantas/ocorrencias e respeitar limite real do servidor; verificar fixtures com limite menor que pageSize, paginas cheias/vazias, IDs repetidos e falha intermediaria sem publicar snapshot parcial.
- [x] 4.4 Implementar publicacao atomica serializada com edicoes locais e limpeza de staging incompleto; verificar falha de disco, encerramento entre lotes e edicao confirmada durante refresh preservando a ultima revisao completa.
- [x] 4.5 Aplicar deadline de 30 segundos por leitura, invalidacao de geracao e protecao contra resultado tardio; verificar timeout seguido de retry sem commit antigo, concorrencia ilimitada ou loading permanente.
- [x] 4.6 Alinhar injecao do Inventario aos repositorios compartilhados e totais por revisao; verificar ausencia de GETs de contagem/referencia repetidos e ausencia de hidratacao integral para totais de cache quente.

## 5. Mapas com trabalho limitado

- [x] 5.1 Avaliar biblioteca espacial compativel com dependencias fixadas e prototipar consulta em worker; entregar decisao com medicao 21k/50k, suporte a pontos coincidentes e teto de 1.000 objetos.
- [x] 5.2 Implementar projecao por viewport/zoom/filtros, coalescimento e descarte de resultados antigos; verificar cobertura completa por contagens, movimento da camera e teto incluindo planta selecionada, sem truncar registros.
- [x] 5.3 Integrar projecao limitada em Fazenda e Inspecao, invalidacao por revisao e atualizacoes pequenas; verificar alteracao de coordenada/non_existent/ocorrencia com mesma quantidade e ausencia de recriacao integral por GPS.
- [x] 5.4 Implementar acesso paginado aos membros de clusters densos no zoom maximo; verificar identificacao/selecao de qualquer membro e regras existentes do editor da Inspecao.
- [x] 5.5 Precomputar bounds e liberar recursos graficos de icones; verificar camera preservada e traces de alocacao apos repetidas montagens/desmontagens.

## 6. Integridade e aceite

- [x] 6.1 Executar testes existentes e novos de cache, banco, repositorios, DI, navegacao, mapas e sincronizacao; verificar `flutter test` e `dart analyze` sem novas falhas, preservando idempotencia e filtros de elegibilidade.
- [ ] 6.2 Automatizar em Android os 50 ciclos de navegacao, 20 retomadas e 10 encerramentos/reaberturas por carga, incluindo escrita/refresh/sync interrompidos; verificar zero perda de trabalho confirmado, ANR ou crash.
- [ ] 6.3 Medir 20 aberturas quentes, 50 transicoes e 60 segundos de pan/zoom em profile; entregar p95 de shell <=2 s, navegacao <=250 ms e UI/raster <=32 ms com 21k, reportando frames de 50k como estresse.
- [ ] 6.4 Medir PSS/heap/nativo nos ciclos estabelecidos e confirmar estabilidade em release; verificar crescimento de PSS <=15% entre medianas especificadas e ausencia de acumulacao de mapas/GPS.
- [ ] 6.5 Consolidar relatorio antes/depois, traces e procedimento de recuperacao/rollback compativel com SQLite; verificar todos os requisitos de aceite e registrar qualquer criterio nao atendido sem marcar a entrega como validada.
