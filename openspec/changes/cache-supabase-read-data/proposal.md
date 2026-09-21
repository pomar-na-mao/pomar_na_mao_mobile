## Why

As telas Fazenda, Inventário e Inspeção consultam repetidamente as mesmas tabelas do Supabase, inclusive com fluxos independentes para `plants`, o que aumenta tráfego, latência e consumo de bateria. O app já possui SQLite para inspeções, mas o cache não é compartilhado pelas demais telas e ainda permite novas leituras remotas ao reabrir destinos ou repetir carregamentos.

## What Changes

- Introduzir um cache local persistente, isolado por projeto Supabase, para os dados de leitura compartilhados de `plants`, `farm`, `zones`, `regions` e `occurrence_types`.
- Fazer leituras concorrentes do mesmo conjunto compartilharem uma única operação e servir dados já persistidos sem repetir GETs ao navegar, reconstruir telas ou reiniciar o app.
- Carregar cada conjunto de referência remotamente apenas quando ainda não existir cache local utilizável; depois do bootstrap, reutilizar o conteúdo persistido sem atualização automática.
- Tornar o botão **Carregar plantas** da tela de Inspeção o único gatilho explícito para atualizar remotamente `plants` depois do bootstrap inicial. O mesmo carregamento também atualiza o estado remoto de ocorrências abertas necessário para editar as plantas com segurança, sem refazer a consulta ao catálogo já armazenado.
- Fazer Fazenda, Inventário e Inspeção consumirem a mesma versão local de plantas; os totais do Inventário passam a ser calculados desse conjunto em vez de executar duas contagens HTTP independentes.
- Preservar o último cache íntegro quando uma atualização falhar e manter sobre ele as alterações de inspeção ainda não sincronizadas.

## Capabilities

### New Capabilities

- `local-read-cache`: Persistência, compartilhamento, bootstrap, deduplicação de leituras e política de atualização dos dados de leitura usados pelas telas do app.

### Modified Capabilities

- `farm-map`: A Fazenda passa a exibir o conjunto de plantas do cache compartilhado e deixa de atualizar `plants` remotamente ao abrir ou tentar novamente quando já houver dados locais.
- `manual-inspection`: O botão Carregar plantas passa a controlar a atualização remota do conjunto compartilhado de plantas e do estado de ocorrências abertas, reutilizando o catálogo local e preservando alterações pendentes.

## Impact

- Afeta os repositórios e fontes de dados de `lib/features/farm`, `lib/features/inventory` e `lib/features/operations`, além da composição em `lib/core/di`.
- Evolui o banco SQLite existente para armazenar o conjunto completo de plantas e os dados geográficos/de referência compartilhados, com migração não destrutiva e escopo por URL do projeto.
- Remove as duas consultas remotas de contagem do Inventário e evita fluxos duplicados de paginação de `plants`; não requer alteração de schema, RPC, RLS ou dependências no Supabase.
- Exige testes de migração, concorrência, persistência entre reinícios, falha de rede, atualização manual e integração entre as três telas.
