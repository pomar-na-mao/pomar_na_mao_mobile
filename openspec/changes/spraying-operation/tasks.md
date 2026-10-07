## 1. Modelos de Domínio e Camada de Persistência Local (SQLite)

- [x] 1.1 Criar os modelos de domínio da pulverização em `lib/features/operations/domain/spraying_models.dart` (`SprayingOperation`, `SprayingRoute`, `SprayingTrackPoint`, `SprayingInput`, `SprayingConfirmedPlant`, `SprayingSessionState`) e verificar compilação sem erros.
- [x] 1.2 Implementar as tabelas e migrações SQLite em `lib/features/operations/data/spraying_database.dart` (`local_spraying_operations`, `local_spraying_routes`, `local_spraying_track_points`, `local_spraying_inputs`, `local_spraying_confirmed_plants`) e verificar inicialização correta do banco.
- [x] 1.3 Implementar a classe `SprayingLocalStore` em `lib/features/operations/data/spraying_local_store.dart` com operações de CRUD para criar sessões, anexar pontos GPS, consolidar rotas, salvar insumos, salvar plantas confirmadas e listar histórico offline.

## 2. Cálculo Geométrico Offline e Comunicação Remota (Supabase RPC)

- [x] 2.1 Implementar utilitário de cálculo geométrico em `lib/features/operations/domain/spraying_geometry_service.dart` para identificar plantas a até 9 metros da rota percorrida com poda espacial por bounding box e verificar cálculo com testes unitários.
- [x] 2.2 Implementar `SprayingRemoteDataSource` e `SprayingRepository` em `lib/features/operations/data/` para serializar o payload e executar a chamada à RPC `sync_reviewed_spraying_operation(p_payload)`, tratando respostas e erros de rede.

## 3. Gestão de Estado e Navegação

- [x] 3.1 Implementar o `SprayingViewModel` em `lib/features/operations/presentation/spraying_view_model.dart` gerenciando os ciclos da sessão (gravação GPS em tempo real, pausa, finalização, cálculo de plantas, revisão e sincronização).
- [x] 3.2 Habilitar o card de Pulverização em `lib/features/operations/presentation/operation_definition.dart` e adicionar a rota de navegação para `SprayingView` em `operations_view.dart`.

## 4. Componentes Visuais e Telas (UI/UX)

- [x] 4.1 Criar o widget `SprayingActionCard` em `lib/features/operations/presentation/widgets/spraying_action_card.dart` seguindo a identidade visual de `InspectionActionCard` com os 4 botões operacionais.
- [x] 4.2 Criar o modal `SprayingSessionModal` para controle de sessão (Iniciar, Pausar e Finalizar gravação de rota).
- [x] 4.3 Criar o modal/interface de revisão `SprayingReviewModal` permitindo ao operador inspecionar plantas calculadas (`auto_matched`), desmarcar plantas ou incluir manualmente (`manual_added`).
- [x] 4.4 Criar o modal `SprayingInputsModal` para registro de operador, máquina/trator e múltiplos insumos aplicados (`productName`, `dose`, `doseUnit`, `inputType`, etc.).
- [x] 4.5 Criar o modal `LocalSprayingsModal` para exibir a listagem de pulverizações salvas no SQLite com status e botão de Sincronizar para itens revisados.
- [x] 4.6 Construir a tela principal `SprayingView` em `lib/features/operations/presentation/spraying_view.dart` integrando o mapa interativo, polyline da rota em tempo real, marcadores de plantas, localização do operador e a barra de ações inferior.

## 5. Documentação Técnica e Validação

- [x] 5.1 Preencher a seção 20.4 do arquivo `database.md` detalhando o fluxo operacional da pulverização, esquema das tabelas SQLite locais e especificação do payload para a RPC `sync_reviewed_spraying_operation`.
- [x] 5.2 Implementar testes unitários e de widget cobrindo cálculo geométrico, serialização da RPC e fluxos do ViewModel.
- [x] 5.3 Executar `dart analyze` no projeto e garantir conformidade sem erros ou advertências pendentes.
