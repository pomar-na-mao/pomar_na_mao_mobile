## ADDED Requirements

### Requirement: Persistir plantas adicionadas em fila propria
O aplicativo SHALL persistir plantas adicionadas pelo mapa em armazenamento local recuperavel, com identificador local estavel, latitude, longitude, `non_existent`, `zone_id` opcional, data de criacao, status de sincronizacao e erro legivel quando houver. Essa fila SHALL ser independente de `local_inspections` e SHALL sobreviver a fechamento de modal, troca de aba, encerramento do aplicativo e falha de rede.

#### Scenario: Recuperar planta adicionada apos reinicio
- **WHEN** o usuario adiciona uma planta pelo mapa, confirma o modal e encerra o aplicativo antes de sincronizar
- **THEN** ao reabrir a Inspecao a planta adicionada permanece disponivel na lista propria
- **AND** seu status continua pendente

#### Scenario: Nao misturar com inspecoes
- **WHEN** existem inspecoes locais e plantas adicionadas pendentes
- **THEN** a lista de Inspecoes salvas contem somente inspecoes
- **AND** a lista de plantas adicionadas contem somente plantas adicionadas pelo mapa

### Requirement: Sincronizar plantas adicionadas por RPC separada
O envio de plantas adicionadas SHALL usar uma RPC separada de `sync_manual_inspection_v2`. A RPC SHALL receber um payload com `deviceId` e uma lista de plantas contendo identificador local, latitude, longitude, `non_existent` e opcionalmente `zoneId`; SHALL inserir ou atualizar linhas em `public.plants` preenchendo apenas `latitude`, `longitude`, `non_existent`, `zone_id`, `local_id`, `device_id`, `sync_status` e `synced_at` quando aplicavel; e SHALL deixar os demais campos de `plants` usarem seus defaults do banco. A sincronizacao SHALL marcar cada item local como sincronizado somente apos resposta remota valida.

#### Scenario: Sincronizar plantas pendentes
- **WHEN** o usuario aciona a sincronizacao de plantas adicionadas com rede disponivel
- **THEN** o aplicativo chama a RPC dedicada com todas as plantas adicionadas pendentes ou com erro
- **AND** cada linha criada em `plants` usa a latitude, longitude, `non_existent` e `zone_id` informados pelo app
- **AND** os demais campos da planta sao preenchidos pelos defaults do banco

#### Scenario: Falha durante sincronizacao
- **WHEN** a RPC falha, a rede esta indisponivel ou a resposta e invalida
- **THEN** os itens locais permanecem reenviaveis com status de erro ou pendente
- **AND** o aplicativo nao indica sincronizacao concluida para esses itens

#### Scenario: Reenvio idempotente
- **WHEN** o aplicativo reenvia uma planta adicionada que ja foi criada remotamente com o mesmo `deviceId` e identificador local
- **THEN** a RPC retorna o mesmo registro remoto ou evita duplicidade
- **AND** o item local pode ser marcado como sincronizado sem criar uma segunda linha em `plants`

### Requirement: Documentar contrato da RPC de plantas adicionadas
`database.md` SHALL documentar a nova RPC no detalhamento separado e no bloco de query unica, incluindo assinatura, payload, retorno, comportamento de insert em `plants`, idempotencia, grants e revokes coerentes com o padrao de RPCs mobile do projeto.

#### Scenario: Consultar detalhamento separado
- **WHEN** um desenvolvedor pesquisa a nova RPC no detalhamento de `database.md`
- **THEN** encontra assinatura, exemplo de payload, campos gravados em `plants` e regras de permissao

#### Scenario: Consultar query unica
- **WHEN** um desenvolvedor usa o bloco "Query Unica" de `database.md`
- **THEN** o bloco contem a definicao executavel da nova RPC e seus grants correspondentes
