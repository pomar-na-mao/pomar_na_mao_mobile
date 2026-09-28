## Purpose

Garantir responsividade e recuperacao verificaveis ao navegar e retomar o aplicativo com grandes pomares, distinguindo travamento, encerramento e espera de dados.

## ADDED Requirements

### Requirement: Validar estabilidade com cargas representativas

O aplicativo SHALL passar pela matriz documentada de 0, 1.000, 21.000 e 50.000 plantas sinteticas em Android fisico, incluindo cache frio/quente, rede indisponivel/lenta, ocorrencias pendentes e coordenadas invalidas. A validacao SHALL registrar aparelho, RAM, Android, build, versoes dos plugins, distribuicao dos dados e resultados antes/depois.

#### Scenario: Repetir navegacao e retomadas
- **WHEN** sao executadas 50 alternancias entre Inventario, Fazenda e Inspecao, 20 ciclos background/retomada e 10 encerramentos/reaberturas por tamanho de carga
- **THEN** nao ocorre ANR, crash, excecao nao tratada ou perda de alteracoes locais confirmadas
- **AND** os testes incluem encerramento durante atualizacao de cache e durante sincronizacao

### Requirement: Atender orcamentos de interacao

No aparelho Android fisico de referencia registrado antes das otimizacoes, o aplicativo SHALL apresentar o shell navegavel em ate 2 segundos no p95 de 20 aberturas com cache quente; SHALL responder a troca de destino em ate 250 ms no p95 de 50 transicoes; e SHALL manter tempos de UI e raster, medidos separadamente, em ate 32 ms no p95 durante 60 segundos de pan/zoom com 21.000 plantas. Os tempos excluem espera por tiles e rede, mas nao excluem hidratacao local ou preparacao de marcadores. A carga de 50.000 SHALL cumprir os mesmos criterios de navegacao e ausencia de falhas; seus tempos de frames SHALL ser reportados como teste de estresse.

#### Scenario: Medir sem mascarar processamento local
- **WHEN** o benchmark usa profile para frames e release para confirmacao de estabilidade
- **THEN** registra as distribuicoes de tempo e evidencia o cumprimento dos limites, sem usar debug como evidencia de desempenho

### Requirement: Limitar recursos visuais em ambos os mapas de plantas

Fazenda e Inspecao SHALL manter no maximo 1.000 objetos de plantas (marcadores individuais mais clusters) enviados ao mapa por estado de viewport, incluindo a planta selecionada. Todas as plantas elegiveis com coordenadas validas SHALL permanecer representaveis por agrupamento ou acesso individual; o limite SHALL NOT ser implementado truncando a lista de plantas.

#### Scenario: Concentracao de plantas no mesmo ponto
- **WHEN** mais de 1.000 plantas compartilham uma area ou coordenada no zoom maximo
- **THEN** o agrupamento informa sua contagem e oferece acesso paginado aos membros para identificar e selecionar cada planta sem exceder o limite visual

### Requirement: Diagnosticar falhas sem registrar dados sensiveis

A instrumentacao SHALL registrar duracoes por etapa, contagens, revisao, quantidade de mapas ativos e motivo de falha, sem payloads de inspecao, credenciais, coordenadas ou identificadores pessoais. O diagnostico SHALL correlacionar erros Dart e evidencias Android de ANR, crash nativo e encerramento por memoria quando disponiveis; ausencia de evidencia SHALL ser classificada como causa desconhecida.

#### Scenario: Encerramento sem excecao Dart
- **WHEN** o processo desaparece e nao ha erro Dart correspondente
- **THEN** o relatorio investiga logs e motivo de saida do Android e nao classifica automaticamente o evento como falha de rede ou excecao Flutter

### Requirement: Estabilizar uso de memoria

O aplicativo SHALL liberar recursos de telas inativas e demonstrar que a mediana do PSS total do processo nos ultimos cinco dos 50 ciclos de navegacao nao supera em mais de 15% a mediana dos ciclos 6 a 10, medidos no mesmo destino apos cinco segundos de repouso. Heap Dart e memoria nativa SHALL ser reportados separadamente para investigacao.

#### Scenario: Repetir abertura de mapas
- **WHEN** os mapas sao abertos e fechados repetidamente com 21.000 e 50.000 plantas
- **THEN** o benchmark cumpre o limite de memoria retida e nao acumula controladores ou subscriptions de localizacao
