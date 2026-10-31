## Purpose

Garantir que lançamentos completos da Atividade sejam duráveis offline e sincronizados de forma segura, atômica e idempotente com o Supabase.

## ADDED Requirements

### Requirement: Manter uma fila local recuperável

O aplicativo SHALL armazenar cada lançamento, sua máquina, sua calda e os snapshots da composição de forma normalizada no dispositivo, com estados `pending`, `syncing`, `error` e `synced`, erro mais recente e identificadores remotos reconciliados. Ao reiniciar, itens deixados em `syncing` SHALL voltar a um estado recuperável.

#### Scenario: Reiniciar com item pendente
- **WHEN** o aplicativo é encerrado após salvar um lançamento e antes da sincronização
- **THEN** o lançamento reaparece na lista local com a geometria, formulário, calda e composição completos

#### Scenario: Recuperar sincronização interrompida
- **WHEN** o aplicativo inicia e encontra um lançamento no estado `syncing`
- **THEN** o sistema o torna novamente elegível para tentativa sem criar uma cópia

### Requirement: Sincronizar um lançamento completo atomicamente

O aplicativo SHALL enviar à operação remota um contrato canônico contendo `deviceId`, identificador local, tipo e GeoJSON da geometria, atividade, instante, responsável, `mixtureId` e `machineId` opcionais. O backend SHALL resolver a composição diretamente de `public.mixture_inputs`, validar todo o contrato e SHALL gravar ou rejeitar o lançamento completo em uma única transação.

#### Scenario: Sincronizar lançamento válido
- **WHEN** o usuário sincroniza um lançamento pendente com contrato válido
- **THEN** o backend cria o cabeçalho operacional, o detalhe geográfico e os snapshots da máquina e da calda/composição e devolve seus identificadores com o instante de sincronização

#### Scenario: Rejeitar calda inválida
- **WHEN** `mixtureId` referencia uma calda inexistente, inativa ou sem composição válida
- **THEN** a transação é revertida, nenhum registro parcial permanece e o item local conserva os dados para correção ou nova tentativa

#### Scenario: Falhar durante a chamada remota
- **WHEN** ocorre erro de rede ou banco durante a sincronização
- **THEN** o lançamento passa a `error`, mantém seus dados locais e pode ser reenviado

### Requirement: Garantir idempotência por dispositivo e identificador local

O backend SHALL identificar unicamente um lançamento por `(device_id, local_id)`. O reenvio do mesmo lançamento SHALL devolver os mesmos identificadores remotos e SHALL NOT duplicar cabeçalho, geometria, calda ou snapshots da composição.

#### Scenario: Repetir payload após resposta perdida
- **WHEN** o mesmo dispositivo reenvia o mesmo identificador local após não receber a resposta anterior
- **THEN** o backend devolve o resultado já consolidado sem criar registros adicionais

#### Scenario: Reutilizar identificador com conteúdo divergente
- **WHEN** o mesmo par dispositivo/identificador local é enviado com conteúdo diferente do já persistido
- **THEN** o backend rejeita o conflito e preserva o lançamento original

### Requirement: Persistir a geometria com semântica espacial

O backend SHALL armazenar a rota como `LineString` e a área como `Polygon`, ambas em SRID 4326 e com índice espacial. A geometria persistida SHALL corresponder ao GeoJSON validado recebido e SHALL estar vinculada de forma exclusiva ao cabeçalho da operação.

#### Scenario: Persistir rota
- **WHEN** o payload declara Rota com ao menos dois pontos distintos
- **THEN** o backend grava uma geometria `LineString` SRID 4326 vinculada à operação

#### Scenario: Persistir área
- **WHEN** o payload declara Área com anel válido e fechado
- **THEN** o backend grava uma geometria `Polygon` SRID 4326 vinculada à operação

#### Scenario: Rejeitar tipo divergente
- **WHEN** o tipo declarado não corresponde ao tipo da geometria GeoJSON
- **THEN** o backend rejeita toda a transação com erro de validação

### Requirement: Preservar histórico da calda

Cada lançamento remoto com calda SHALL referenciar `public.mixtures` e SHALL preservar o nome da receita e snapshots de seus componentes, incluindo referência ao insumo, nome, princípio ativo, dose de bula, unidade e dose da calda. Alterações posteriores nos catálogos SHALL NOT reescrever o histórico.

#### Scenario: Receita muda após sincronização
- **WHEN** o nome, a composição ou a dose de uma calda é alterada depois da sincronização
- **THEN** o lançamento existente mantém os valores históricos e a referência à receita selecionada

#### Scenario: Excluir catálogo referenciado
- **WHEN** uma calda ou insumo já utilizado é alvo de exclusão no catálogo
- **THEN** a integridade histórica impede perda silenciosa da referência ou dos snapshots do lançamento

### Requirement: Preservar histórico da máquina

Cada lançamento remoto com máquina SHALL referenciar `public.machines`, preservar snapshots de nome e marca e registrar o nome em `field_operations.machine_name`. Alterações posteriores no catálogo SHALL NOT reescrever o histórico.

#### Scenario: Máquina muda após sincronização
- **WHEN** o cadastro da máquina é alterado depois da sincronização
- **THEN** o lançamento mantém a referência e os valores históricos registrados

### Requirement: Restringir mutações remotas à RPC validada

As tabelas da Atividade SHALL ter RLS habilitada e SHALL impedir escrita direta por clientes `anon` e `authenticated`. A RPC SHALL aceitar os papéis usados pelo aplicativo, validar `auth.uid()` quando presente, limitar o tamanho do lote e da geometria e executar com privilégios mínimos e `search_path` fixo.

#### Scenario: Tentar inserção direta
- **WHEN** um cliente móvel tenta inserir diretamente em uma tabela da Atividade
- **THEN** o banco nega a operação

#### Scenario: Sincronizar pelo contrato público
- **WHEN** um cliente permitido chama a RPC com payload válido
- **THEN** somente as mutações previstas pelo contrato são executadas e `created_by` registra o usuário autenticado quando houver sessão

#### Scenario: Enviar payload excessivo
- **WHEN** o lote, a quantidade de vértices ou o tamanho textual ultrapassa os limites documentados
- **THEN** a RPC rejeita a solicitação antes de persistir qualquer registro

### Requirement: Sincronizar individualmente ou em lote

O aplicativo SHALL permitir sincronizar um lançamento ou todos os lançamentos elegíveis, impedir disparos concorrentes duplicados e reconciliar cada resultado independentemente no armazenamento local.

#### Scenario: Sincronizar um item
- **WHEN** o usuário aciona Sincronizar em um lançamento pendente ou com erro
- **THEN** somente esse lançamento é enviado e seu estado é atualizado conforme o resultado

#### Scenario: Sincronizar todos com resultado parcial de transporte
- **WHEN** a sincronização em lote retorna resultados válidos para apenas parte dos identificadores esperados
- **THEN** os resultados presentes são reconciliados e os itens sem resposta permanecem recuperáveis com erro explícito

### Requirement: Excluir uma operação do armazenamento local

O aplicativo SHALL permitir excluir uma operação ainda não sincronizada exibida em Operações salvas após confirmação explícita. A exclusão SHALL remover a operação e seus snapshots de calda/composição somente do SQLite do dispositivo. Para operações já sincronizadas, o botão de exclusão SHALL permanecer desabilitado.

#### Scenario: Cancelar a exclusão
- **WHEN** o usuário aciona Excluir e cancela a confirmação
- **THEN** a operação, sua calda e composição permanecem na lista local sem alteração

#### Scenario: Confirmar a exclusão local
- **WHEN** o usuário confirma a exclusão de uma operação pendente ou com erro
- **THEN** a operação e seus snapshots de calda/composição são removidos do dispositivo e a lista é atualizada imediatamente

#### Scenario: Impedir a exclusão de uma operação sincronizada
- **WHEN** uma operação da lista local já possui estado sincronizado
- **THEN** o botão de exclusão permanece desabilitado e nenhuma confirmação ou remoção é executada
