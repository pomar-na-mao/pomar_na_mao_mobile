## Purpose

Garantir a persistência local em SQLite das marcações de Previsão de Safra e sua sincronização individual ou em lote com o Supabase, vinculando espacialmente cada marcação à planta mais próxima e mantendo um único registro por `plant_id` via substituição (`UPSERT`).

## ADDED Requirements

### Requirement: Persistir marcações de Previsão de Safra localmente no dispositivo

O sistema SHALL armazenar cada marcação de Previsão de Safra em uma tabela SQLite local contendo identificador local, `latitude`, `longitude`, `classification` (`N`, `P`, `M`, `G` ou `GG`), data e hora do registro (`created_at`) e estado de sincronização (`pending`, `syncing`, `error`, `synced`), preservando os dados entre reinícios do aplicativo.

#### Scenario: Persistência e ordenação local
- **WHEN** o usuário registra novas marcações de Previsão de Safra ou reinicia o aplicativo
- **THEN** todas as marcações permanecem salvas localmente e são listadas da mais nova para a mais antiga (`created_at DESC`)

### Requirement: Sincronizar marcações individualmente e em lote

Na lista de **Marcações salvas**, assim como no MIPD e nas demais telas operacionais, o sistema SHALL disponibilizar um botão individual para sincronizar cada registro e um botão para sincronizar todos os registros pendentes/com erro.

#### Scenario: Sincronizar um registro individualmente
- **WHEN** o usuário aciona o botão de sincronização individual de uma marcação
- **THEN** o sistema envia aquela marcação para a RPC do Supabase e atualiza seu status local para sincronizado em caso de sucesso, ou registra o erro em caso de falha

#### Scenario: Sincronizar todos os registros pendentes
- **WHEN** o usuário aciona o botão de sincronizar todos na lista de **Marcações salvas**
- **THEN** o sistema sincroniza item a item os registros não sincronizados e atualiza o status individual de cada registro conforme o resultado

### Requirement: Associar à planta mais próxima e substituir registro existente por plant_id no Supabase

Ao sincronizar cada item, a RPC no Supabase SHALL localizar a planta mais próxima a partir da posição (`latitude` e `longitude`) recebida na marcação e gravar um registro na nova tabela do Supabase com as colunas:
- `id`: `uuid` único, gerado ao criar o registro na tabela;
- `plant_id`: `uuid` único da planta mais próxima encontrada;
- `zone_id`: `uuid` correspondente à coluna `plants.zone_id` da planta encontrada;
- `classification`: classificação recebida (`N`, `P`, `M`, `G` ou `GG`);
- `latitude`: latitude recebida do registro na sincronização;
- `longitude`: longitude recebida do registro na sincronização;
- `created_at`: data/hora de registro da marcação recebida na sincronização do dispositivo;
- `updated_at`: data/hora de atualização do registro, gerada como data atual (`now()`) pela RPC (não enviada pelo dispositivo).

Caso já exista um registro na tabela para o `plant_id` encontrado, a RPC SHALL substituir/atualizar o registro atual em vez de gerar outro, mantendo a unicidade de `plant_id`.

#### Scenario: Sincronizar marcação para uma planta ainda sem previsão de safra
- **WHEN** um registro é sincronizado e a planta mais próxima encontrada ainda não possui registro na tabela remota
- **THEN** a RPC cria um novo registro com `id` gerado, `plant_id` e `zone_id` da planta mais próxima, `classification`, `latitude`, `longitude`, `created_at` do dispositivo e `updated_at` gerado pela RPC com a data/hora atual

#### Scenario: Sincronizar marcação para uma planta que já possui previsão de safra
- **WHEN** um registro é sincronizado e a planta mais próxima encontrada já possui um registro com o mesmo `plant_id` na tabela remota
- **THEN** a RPC substitui os dados do registro existente daquele `plant_id` (`zone_id`, `classification`, `latitude`, `longitude`, `created_at` e `updated_at = now()`) sem duplicar linhas na tabela

### Requirement: Entregar migration SQL e atualizar documentação sem alterar o Supabase via MCP

A implementação SHALL gerar um arquivo de migration SQL em `supabase/migrations` contendo a criação da nova tabela e da RPC, sem executar modificações no Supabase por ferramentas MCP, e SHALL atualizar o arquivo `database.md` nos itens **20** e **25**.

#### Scenario: Verificar artefatos de banco e documentação
- **WHEN** a implementação da funcionalidade for concluída
- **THEN** existe o arquivo de migration SQL com a definição da tabela e da RPC em `supabase/migrations`
- **AND** o arquivo `database.md` está atualizado nos itens 20 e 25 com a documentação do processo e o SQL correspondente
