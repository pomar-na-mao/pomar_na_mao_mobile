## Purpose

Definir a persistência offline e a sincronização segura e idempotente das marcações MIPD, incluindo evidências fotográficas privadas e rastreabilidade no banco operacional.

## ADDED Requirements

### Requirement: Persistir uma fila MIPD recuperável

O aplicativo SHALL persistir em SQLite cada marcação com identificador local estável, planta, tipo de ocorrência, partes afetadas, data da observação, caminho opcional da foto e estado de sincronização. A fila SHALL sobreviver ao reinício do aplicativo, e uma foto capturada SHALL ser copiada para um diretório durável gerenciado pelo aplicativo antes de a marcação ser confirmada.

#### Scenario: Reabrir o aplicativo com marcações pendentes
- **WHEN** o aplicativo é reiniciado após salvar marcações sem sincronizá-las
- **THEN** os itens e suas fotos locais continuam disponíveis com estado pendente

#### Scenario: Recuperar sincronização interrompida
- **WHEN** o aplicativo é encerrado enquanto um item está marcado como sincronizando
- **THEN** a próxima inicialização devolve o item a um estado seguro e novamente sincronizável

### Requirement: Listar e sincronizar marcações salvas

A tela Marcações salvas SHALL exibir os dados essenciais, a foto quando disponível, o estado e o erro recuperável de cada item. O usuário SHALL poder sincronizar um item individual ou todos os itens pendentes, sem bloquear a consulta dos demais registros.

#### Scenario: Sincronizar um item
- **WHEN** o usuário aciona Sincronizar em uma marcação pendente
- **THEN** somente aquela marcação percorre o fluxo de upload e RPC e seu estado é atualizado com o resultado

#### Scenario: Sincronizar toda a fila
- **WHEN** o usuário aciona Sincronizar todas
- **THEN** o aplicativo processa todas as marcações elegíveis, mantém falhas como recuperáveis e informa o resultado por item

### Requirement: Armazenar fotos em bucket privado

Quando uma marcação possuir foto, o aplicativo SHALL enviá-la antes da RPC para um bucket privado dedicado ao MIPD, usando o cliente autenticado e um caminho determinístico vinculado ao usuário, dispositivo e identificador local. O upload SHALL ser repetível sem gerar objetos duplicados e SHALL persistir o caminho remoto antes de iniciar a mutação no banco.

#### Scenario: Sincronizar uma marcação com foto
- **WHEN** o upload autenticado termina com sucesso
- **THEN** o aplicativo persiste o caminho remoto e o inclui no payload da RPC

#### Scenario: Upload da foto falha
- **WHEN** o upload falha antes da RPC
- **THEN** a RPC não é chamada para aquela marcação e o item permanece recuperável para nova tentativa

#### Scenario: Sincronizar uma marcação sem foto
- **WHEN** a marcação não possui foto
- **THEN** o aplicativo chama a RPC sem caminho de objeto e a ausência de foto não impede o processamento

### Requirement: Sincronizar marcações pela RPC MIPD

O backend SHALL expor a RPC autenticada `sync_mipd_markings(p_payload jsonb)`. O payload SHALL identificar o dispositivo e conter uma ou mais marcações com identificador local, planta, tipo de ocorrência, partes afetadas, instante observado e caminho opcional da foto. A resposta SHALL informar o resultado e os identificadores remotos por marcação para permitir conciliação individual e em lote.

#### Scenario: Enviar uma marcação válida
- **WHEN** um usuário autenticado envia uma marcação válida
- **THEN** a RPC devolve sucesso para o identificador local e os identificadores remotos criados ou reutilizados

#### Scenario: Rejeitar payload inválido
- **WHEN** faltam identificadores obrigatórios, não há parte afetada, existe parte fora do conjunto permitido ou o tipo não pertence a `PEST_DISEASE`
- **THEN** a RPC rejeita a mutação com erro explícito e não grava um estado parcial

#### Scenario: Rejeitar chamada não autenticada
- **WHEN** a RPC é chamada sem usuário autenticado
- **THEN** o banco nega a execução e não cria registros operacionais

### Requirement: Registrar a operação e a ocorrência fitossanitária

Para cada marcação válida, a RPC SHALL criar ou reutilizar um `field_operations` com tipo de operação `mipd`, `source = 'mpid'` e `target_occurrence_type_id` correspondente. A mesma transação SHALL gravar `plant_operation_history`, criar ou atualizar a ocorrência aberta aplicável em `plant_occurrences`, registrar o evento correspondente em `plant_occurrence_events` e persistir os dados exclusivos do MIPD em uma tabela vinculada à operação, planta e ocorrência.

#### Scenario: Registrar nova ocorrência na planta
- **WHEN** não existe ocorrência aberta equivalente para a planta e o tipo informado
- **THEN** a RPC cria a ocorrência, registra o evento de inclusão e vincula as partes e a foto à operação MIPD

#### Scenario: Atualizar ocorrência já aberta
- **WHEN** já existe ocorrência aberta equivalente para a planta e o tipo informado
- **THEN** a RPC reutiliza ou atualiza a ocorrência conforme a regra da Inspeção, registra o evento de atualização e preserva a marcação MIPD como evidência própria

### Requirement: Garantir idempotência e atomicidade por lote

A RPC SHALL usar o par dispositivo/identificador local como chave idempotente de cada marcação e SHALL devolver o mesmo resultado lógico em tentativas repetidas. Todas as gravações de um lote de banco SHALL ocorrer em uma única transação; uma falha SHALL impedir a confirmação parcial daquele lote, sem incluir o upload de Storage na transação.

#### Scenario: Repetir o mesmo payload
- **WHEN** o cliente repete um payload já concluído com o mesmo dispositivo e identificadores locais
- **THEN** a RPC reutiliza os registros consolidados e não duplica operação, histórico, ocorrência, evento ou detalhe MIPD

#### Scenario: Falhar durante o lote
- **WHEN** uma marcação do lote viola uma validação ou constraint antes da confirmação
- **THEN** nenhuma mutação de banco daquele lote é confirmada e o cliente mantém os itens para conciliação ou nova tentativa

### Requirement: Restringir dados e fotos ao acesso autorizado

A migration SHALL habilitar RLS na nova tabela, conceder somente os privilégios necessários ao papel `authenticated` e criar políticas de Storage que restrinjam leitura, criação, atualização e exclusão ao proprietário e ao prefixo autenticado. O cliente SHALL NOT usar chave de serviço ou manipular diretamente as tabelas internas do Storage.

#### Scenario: Usuário tenta acessar foto de outro proprietário
- **WHEN** um usuário autenticado solicita um objeto fora de seu prefixo ou que não lhe pertence
- **THEN** a política nega o acesso

#### Scenario: Cliente autenticado repete upload próprio
- **WHEN** o usuário repete o upload no mesmo caminho determinístico sob seu prefixo
- **THEN** as políticas permitem as operações necessárias ao upsert sem ampliar acesso a objetos de terceiros

