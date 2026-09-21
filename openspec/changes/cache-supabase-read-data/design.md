## Context

Consulte `proposal.md` para a motivação e `specs/` para o comportamento esperado. Hoje existem três caminhos independentes de leitura: Fazenda pagina `plants` e consulta `farm`, `zones` e `regions`; Inventário repete as consultas geográficas e faz duas contagens HTTP de `plants`; Inspeção pagina outra projeção de `plants`, consulta `occurrence_types` e `plant_occurrences`, e mantém seu próprio snapshot em SQLite. Os ViewModels são duradouros no `IndexedStack`, mas os repositórios não compartilham estado nem operações em andamento.

O arquivo SQLite de inspeções já é isolado pelo `origin` da URL Supabase, contém dados locais que não podem ser perdidos e sobrepõe mudanças pendentes ao substituir um snapshot. A solução deve preservar essa fila, continuar suportando mais de mil registros e não exigir mudança no banco remoto. A documentação atual do cliente Dart confirma que cada `select()` usa a Data API e que cargas extensas devem continuar paginadas; o cache é responsabilidade do aplicativo.

## Goals / Non-Goals

**Goals:**

- Ter uma única fonte local para cada conjunto lido por mais de uma feature e uma única carga remota por chave quando o cache estiver ausente.
- Distinguir “ainda não carregado” de “carregado e vazio” por metadados, evitando GETs repetidos em tabelas vazias.
- Atualizar o cache de plantas de forma atômica e avisar consumidores vivos sem obrigá-los a consultar o Supabase.
- Preservar snapshots de inspeção, mudanças pendentes e compatibilidade com instalações que já possuem o banco versão 1.
- Tornar a redução de chamadas verificável por contadores em fontes remotas falsas e testes entre repositórios.

**Non-Goals:**

- Adicionar TTL, sincronização em segundo plano, Realtime ou botão de atualização para dados de referência.
- Alterar tabelas, funções, índices ou políticas no Supabase.
- Fazer cache de tiles do Google Maps ou das respostas de autenticação/RPC.
- Resolver conciliação entre dispositivos; permanece a semântica já definida para a RPC de inspeção.

## Decisions

### 1. Evoluir o banco existente para um armazenamento local compartilhado

O `InspectionDatabase` será evoluído, ou renomeado sem trocar o arquivo físico, para atender também aos repositórios de leitura. Uma migração incremental adicionará metadados por conjunto e tabelas para limite da fazenda, zonas e pontos de região. `occurrence_types` e `cached_plants` serão reaproveitadas para não duplicar o estado que a inspeção já protege.

Cada conjunto terá uma chave de metadados e data de carga. Regiões usarão uma chave por zona. A presença do metadado, e não a quantidade de linhas, indicará que o conjunto foi obtido por completo; assim um resultado vazio continua sendo um cache válido. Todas as substituições ocorrerão em transação e só atualizarão o metadado no final.

O JSON de `cached_plants` passará a conter o menor registro compartilhado necessário: `id`, coordenadas, descrição, `zone_id`, `non_existent` e ocorrências abertas. Fazenda e Inventário projetam seus modelos a partir desses campos; Inspeção filtra `non_existent = false` e aplica o estado de ocorrências. Isso elimina as duas paginações independentes atuais e as consultas remotas de contagem.

Na migração da versão 1, os registros existentes serão preservados como fallback de inspeção, mas o conjunto será marcado como incompleto porque a versão antiga continha apenas plantas elegíveis e não permite calcular o total de posições disponíveis. Fazenda e Inventário exigirão o primeiro bootstrap completo; Inspeção ainda poderá retomar o snapshot legado offline. A primeira carga completa substituirá o fallback e marcará o conjunto como completo.

Foi considerada a criação de um segundo banco ou de caches por feature. Isso manteria coordenação, migração e invalidação duplicadas e permitiria versões divergentes da mesma planta. Também foi descartado guardar apenas memória: não reduziria chamadas após reinício e não sustentaria o fluxo offline existente.

### 2. Introduzir um repositório coordenador com leitura cache-first e single-flight

Uma instância criada em `AppDependencies` será dona das fontes remotas, do armazenamento local e de um registro de operações em andamento por chave. Uma leitura comum seguirá esta ordem:

1. ler o conjunto local e seu metadado;
2. retorná-lo imediatamente quando estiver completo;
3. na ausência, reutilizar uma operação remota da mesma chave ou iniciar uma;
4. validar, persistir em transação e publicar a nova revisão;
5. remover a operação do registro tanto em sucesso quanto em erro.

Uma carga de várias páginas continua sendo uma única operação lógica. Solicitações simultâneas de Fazenda e Inventário aguardam o mesmo `Future`, enquanto chaves independentes podem carregar em paralelo. Leituras durante uma atualização manual recebem a versão local íntegra existente; o botão da Inspeção aguarda o resultado da atualização.

O coordenador publicará revisões de plantas por um contrato observável simples, como `Stream` broadcast ou `Listenable`. `FarmMapViewModel`, `InventoryViewModel` e `InspectionViewModel` atualizam suas projeções ao receber uma revisão e não voltam à rede. A assinatura e o encerramento desses listeners seguirão o ciclo de vida dos ViewModels.

Foi considerada apenas memoização nos repositórios atuais. Ela não sobrevive ao processo, não coordena instâncias distintas de `SupabaseFarmRemoteDataSource` e deixa Inventário e Inspeção com representações incompatíveis.

### 3. Separar bootstrap de plantas de atualização explícita

O método de leitura comum poderá buscar remotamente `plants` somente quando não houver uma versão completa. Depois disso, ele sempre retorna SQLite. Um segundo comando explícito, usado exclusivamente por **Carregar plantas**, força nova carga paginada mesmo com cache.

A fonte remota compartilhada consultará uma projeção única (`id`, `latitude`, `longitude`, `description`, `zone_id`, `non_existent`) ordenada por `id` e paginada por `range`. O conjunto completo inclui registros existentes e posições disponíveis; cada consumidor filtra localmente. Parsing e projeções volumosas continuam fora da thread de interface.

Uma resposta remota vazia é válida quando todas as páginas terminam normalmente. Uma página com erro, parsing inválido ou falha ao obter as ocorrências abertas aborta a atualização e mantém a revisão anterior. Não haverá escrita progressiva de páginas no cache visível.

Fazenda poderá repetir apenas um bootstrap que falhou sem cache. Seus controles de retry não forçam refresh quando há uma versão completa. Inventário deixa de usar `count(CountOption.exact)` e calcula os dois totais em uma passagem local.

Foi considerada a proibição de qualquer carga automática, inclusive na primeira instalação. Isso deixaria Fazenda e Inventário vazios até o usuário descobrir o botão dentro de Inspeção. O bootstrap único preserva o uso inicial; “Carregar plantas” controla somente atualizações posteriores.

### 4. Tratar catálogo e ocorrências abertas com ciclos diferentes

`farm`, `zones`, `regions` e `occurrence_types` são conjuntos de referência cache-aside sem TTL. Cada um é consultado somente quando sua chave ainda não tem cache completo. Não haverá atualização automática ou acoplada ao botão de plantas para esses conjuntos.

Ocorrências abertas são estado operacional da planta, não catálogo. O comando **Carregar plantas** buscará `plant_occurrences` depois de obter as plantas e antes do commit local, porque editar com um estado parcial poderia transformar uma ocorrência existente em ação incorreta. A consulta continuará paginada para grandes volumes e aplicará apenas IDs das plantas elegíveis. Se o catálogo ainda não existir, ele será inicializado uma vez antes de publicar um snapshot editável.

O commit de plantas recompõe o estado remoto e depois reaplica, em ordem, as mudanças de inspeções locais não sincronizadas. Plantas removidas remotamente mas ainda referenciadas por mudanças pendentes permanecem como registros inelegíveis de auditoria até a sincronização, preservando o comportamento atual.

Foi considerada a atualização de `occurrence_types` em todo clique. O catálogo muda raramente e essa leitura é uma das repetições observadas; se no futuro for necessária invalidação administrativa, ela deverá ganhar uma ação ou política própria em outra mudança.

### 5. Manter contratos de feature e concentrar a política na camada de dados

Os contratos de domínio serão ajustados para distinguir leitura normal de atualização explícita, sem expor SQLite ou Supabase à apresentação. Os repositórios de Fazenda, Inventário e Inspeção usarão o coordenador injetado; fontes remotas permanecerão pequenas e testáveis.

O fluxo de sincronização por RPC e as tabelas de fila local não mudam. O refresh de plantas apenas usa as mesmas transações locais para preservar/recuperar alterações pendentes. Mensagens atuais de vazio, erro e dados locais serão mantidas, com a diferença de que falha de refresh com cache deixa a versão anterior visível.

### 6. Verificar a redução de chamadas por comportamento

Testes do coordenador usarão fontes falsas com contadores e barreiras controláveis para provar: uma chamada por cache ausente, zero chamadas após persistência/reabertura, uma única chamada para consumidores concorrentes, nova chamada somente no comando explícito e retry após falha. Cargas paginadas verificarão que cada faixa é requisitada uma vez e que página parcial não é publicada.

Testes de migração abrirão um banco versão 1 com snapshot e inspeção pendente, migrarão para a nova versão e confirmarão que nenhum lote, mudança, identidade da instalação ou fallback de inspeção foi perdido. Testes de integração validarão que uma atualização manual altera Fazenda e Inventário, mantém toggles pendentes e não dispara GETs adicionais nesses consumidores.

## Risks / Trade-offs

- [Dados de referência podem ficar desatualizados indefinidamente] → Esse é o custo intencional da política solicitada; limpar os dados do app refaz o bootstrap, e uma invalidação explícita poderá ser adicionada quando houver um caso de uso definido.
- [Baixar todas as plantas no primeiro uso custa mais que as duas contagens do Inventário] → Executar apenas uma vez, projetar somente campos compartilhados, paginar e reutilizar o mesmo conjunto em três features.
- [Uma atualização de ocorrências abertas pode exigir várias páginas] → Manter paginação e single-flight; a correção da edição offline prevalece sobre publicar plantas com estado incompleto.
- [Migração pode confundir o snapshot legado parcial com cache completo] → Criar metadado explícito de completude e testar banco versão 1; somente uma carga completa promove o conjunto.
- [Atualização manual concorrente com leitura ou outro clique] → Compartilhar a mesma operação de plantas, manter a revisão anterior legível e desabilitar/ignorar novos cliques enquanto o comando estiver em andamento.
- [Uma nova revisão pode causar reconstrução pesada do mapa] → Publicar uma revisão por commit, manter parsing fora da UI e reutilizar a memoização/clustering já existente.
- [Rollback para um binário que conhece apenas a versão 1 do banco pode falhar] → Rollback deve usar uma build de compatibilidade no mesmo número de schema; nunca apagar o banco, pois ele contém inspeções pendentes.

## Migration Plan

1. Adicionar a migração SQLite e testes de versão 1 para a nova versão antes de trocar qualquer repositório.
2. Implementar armazenamento e coordenador compartilhados, incluindo metadados, single-flight, paginação, publicação de revisões e overlay de mudanças pendentes.
3. Migrar Fazenda e dados geográficos para leitura cache-first; depois migrar Inventário para totais locais e remover as consultas de contagem.
4. Conectar Inspeção ao mesmo conjunto, reservar o comando forçado para **Carregar plantas** e validar catálogo/ocorrências antes do commit.
5. Executar análise estática, testes unitários/widget e integração com contadores de chamadas; validar manualmente reinício, offline, cache vazio e refresh com inspeção pendente.

Se for necessário reverter a entrega, publicar uma build de compatibilidade que preserve o novo número de schema e volte a usar os fluxos remotos antigos sem remover tabelas ou dados. Uma reversão destrutiva do arquivo SQLite não é aceitável.
