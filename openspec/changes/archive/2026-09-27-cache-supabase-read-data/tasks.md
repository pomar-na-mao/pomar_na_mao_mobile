## 1. Persistência compartilhada

- [x] 1.1 Evoluir o banco SQLite com metadados de completude e tabelas para fazenda, zonas e regiões, preservando `installation`, inspeções, mudanças, catálogo e plantas da versão 1; verificar com testes de criação limpa e migração de um banco v1 contendo rascunho e lote pendente.
- [x] 1.2 Ampliar o registro local de plantas para representar `description`, `zone_id`, `non_existent` e ocorrências abertas, mantendo snapshots legados como fallback incompleto; verificar round-trip de registros existentes, não existentes, coordenadas nulas e cache legado.
- [x] 1.3 Implementar operações transacionais de leitura e substituição para plantas e dados de referência, usando metadados para distinguir ausente de vazio; verificar que resultados vazios permanecem em cache e que uma falha antes do commit conserva a versão anterior.
- [x] 1.4 Preservar o overlay ordenado de mudanças de inspeção não sincronizadas durante a substituição de plantas e reter plantas remotas removidas como inelegíveis quando ainda forem referenciadas; verificar com testes de add/remove pendente e planta ausente no novo snapshot.

## 2. Coordenação de cache e fontes remotas

- [x] 2.1 Unificar a leitura remota paginada de `plants` com a projeção compartilhada e manter a paginação de ocorrências abertas para plantas elegíveis; verificar limites de página, conjunto acima de mil registros, projeção de colunas e filtragem de IDs em testes da fonte Supabase.
- [x] 2.2 Implementar o coordenador cache-first para `farm`, `zones`, `regions` e `occurrence_types`, com uma chave por conjunto/região e deduplicação single-flight; verificar uma chamada no cache ausente, zero chamadas no cache presente, compartilhamento concorrente e retry depois de erro.
- [x] 2.3 Implementar bootstrap único de plantas, leitura local posterior e comando separado de atualização explícita; verificar que leituras comuns não refazem GET, que dois consumidores sem cache compartilham a carga e que somente o comando explícito gera nova paginação após o bootstrap.
- [x] 2.4 Tornar a atualização explícita atômica entre plantas e ocorrências abertas e publicar uma revisão apenas após sucesso completo; verificar que falha em qualquer página mantém a revisão anterior e que leitores durante o refresh continuam recebendo dados íntegros.
- [x] 2.5 Expor e encerrar corretamente o canal de revisões de plantas para consumidores ativos; verificar que cada commit emite uma revisão, falhas não emitem e listeners removidos não recebem eventos.

## 3. Integração das features

- [x] 3.1 Compor uma única instância do banco, coordenador e fontes remotas em `AppDependencies`, injetá-la nos repositórios das três features e fechar seus recursos uma única vez; verificar os testes do container de dependências e do ciclo de descarte.
- [x] 3.2 Migrar Fazenda para plantas e geografia cache-first, mantendo parsing fora da UI, filtros, clustering e retry apenas do bootstrap sem cache; verificar que abrir/reabrir a tela com cache não chama Supabase e que uma revisão da Inspeção atualiza o mapa.
- [x] 3.3 Migrar Inventário para calcular os dois totais do conjunto local completo e usar o cache geográfico, removendo as duas consultas `count` remotas; verificar contagens de `non_existent` verdadeiro/falso, cache vazio, atualização por revisão e ausência de GET próprio ao recarregar a tela.
- [x] 3.4 Migrar Inspeção para ler o snapshot compartilhado sem refresh automático e reservar a atualização forçada para o botão **Carregar plantas**, inicializando o catálogo apenas se ausente; verificar filtro `non_existent = false`, retomada offline, catálogo reutilizado e uma nova chamada ao clicar no botão.
- [x] 3.5 Manter mensagens e estados de vazio, cache local e erro nas três telas, deixando a versão anterior visível quando o refresh manual falhar; verificar com testes de ViewModel/widget para primeira falha, cache confirmado vazio e falha com dados anteriores.

## 4. Verificação integrada

- [x] 4.1 Adicionar um teste de integração com fontes contadoras que percorra Inventário, Fazenda e Inspeção, reinicie o armazenamento e execute Carregar plantas; verificar uma única carga inicial por conjunto, nenhuma repetição após reinício e exatamente uma nova carga de plantas/ocorrências pelo botão.
- [x] 4.2 Executar toda a suíte Flutter e corrigir regressões, verificando que todos os testes terminam com sucesso.
- [x] 4.3 Executar `dart analyze` e a formatação dos arquivos alterados, verificando ausência de erros, avisos e diferenças de formatação.
- [ ] 4.4 Validar manualmente em uma build de desenvolvimento os fluxos online, offline e refresh com inspeção pendente, registrando as requisições para confirmar que apenas páginas necessárias do bootstrap e o botão **Carregar plantas** acessam novamente `plants`.
