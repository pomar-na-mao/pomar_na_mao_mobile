## 1. Confirmar contrato remoto

- [x] 1.1 Recuperar acesso ao MCP Supabase e inspecionar o projeto configurado, tabelas `plants`, `occurrence_types`, `field_operations`, `plant_operation_history`, `plant_occurrences`, `plant_occurrence_events` e a definição de `sync_manual_inspection`; verificar entregando registro da assinatura, retorno, grants, índices de idempotência e diferenças em relação à seção 24 de `database.md`.
- [x] 1.2 Confirmar leitura com as credenciais públicas do app, `operation_types.code = 'manual_inspection'` e compatibilidade da RPC com eventos `added`, `updated`, `removed`; verificar com consultas de metadados e registrar se a função atual será reutilizada.
- [x] 1.3 Se a função implantada não atender ao contrato, criar uma RPC com novo nome via MCP preservando a existente, registrar a alteração SQL conforme o fluxo do repositório e revisar permissões/advisors; verificar em ambiente de teste adição, atualização, resolução, no-op e reenvio nas quatro tabelas. Se não for necessária, registrar a justificativa de dispensa desta tarefa condicional.

## 2. Domínio e persistência local

- [x] 2.1 Adicionar dependências compatíveis para SQLite, caminhos e UUID e o backend SQLite de teste; verificar resolução de dependências e atualização do lockfile.
- [x] 2.2 Definir modelos imutáveis de tipo, snapshot, inspeção, transição, estado de sincronização e retorno RPC seguindo as classes manuais existentes; verificar testes de mapeamento, nulos opcionais, horários UTC e payload com nomes exatos do contrato.
- [x] 2.3 Implementar abertura e migrations versionadas do SQLite, isolamento por projeto, identidade persistente da instalação, tabelas, constraints e índices descritos no design; verificar criação, reabertura, transações e isolamento usando banco temporário nos testes.
- [x] 2.4 Implementar datasource/repositório local para snapshot completo, catálogo, único rascunho ativo e diário de mudanças; verificar recuperação após reinício, rollback de gravação com falha e preservação da ordem em toggles rápidos com relógio injetado.
- [x] 2.5 Implementar finalização transacional, agrupamento somente das plantas alteradas e payload imutável; verificar que duas plantas geram um lote, plantas apenas visualizadas ficam fora e edições posteriores recebem nova inspeção.

## 3. Consulta e sincronização

- [x] 3.1 Implementar datasource Supabase de inspeção com filtro `non_existent = false`, ordenação e paginação de plantas, catálogo e ocorrências abertas em lotes; verificar testes acima de 1.000 registros, vazio, coordenadas inválidas e falha parcial, sem alterar a consulta da Fazenda.
- [x] 3.2 Implementar cache completo e composição do estado remoto com alterações locais pendentes; verificar edição offline, recarga sem perda de mudanças e bloqueio de edição quando o estado inicial é desconhecido.
- [x] 3.3 Implementar chamada RPC com `p_payload` e parser da resposta canônica; verificar parâmetros exatos, quatro campos do retorno e sucesso com contadores zero em retry.
- [x] 3.4 Implementar fila serial de inspeções finalizadas e recuperação de `syncing` interrompido; verificar toques repetidos, ordem entre lotes, parada após erro anterior, timeout e reutilização exata das identidades após resposta perdida.
- [x] 3.5 Persistir confirmação, ID remoto, erro e timestamps no SQLite sem excluir histórico; verificar que falha no commit local após sucesso remoto permite retry e que listagem permanece disponível sem rede.

## 4. ViewModel e navegação

- [x] 4.1 Implementar ViewModel de inspeção com estados separados de carregamento, localização, edição e envio, injetando repositório e `LocationService`; verificar testes para GPS indisponível, seleção múltipla, finalização de todas as plantas e mensagens distintas de salvo/sincronizado.
- [x] 4.2 Registrar serviços, repositórios, banco e ViewModel em `AppDependencies`/`AppScope`; verificar testes da DI e descarte de recursos, sem introduzir outro gerenciador de estado.
- [x] 4.3 Integrar navegação interna de Operações ao `MainShell`; verificar retorno modal → inspeção → operações, barra única persistente, troca entre quatro abas e preservação do rascunho/rota.
- [x] 4.4 Integrar ciclo de localização e mapa à visibilidade da inspeção; verificar assinatura única do stream, suspensão ao sair da aba, cancelamento ao fechar e ausência de recentralização forçada após gesto manual.

## 5. Interface de inspeção

- [x] 5.1 Substituir o placeholder pelo mapa com posição atual, zoom, marcadores e seleção individual; verificar widget com mapa substituível em testes e interação no dispositivo, incluindo clusters quando usados.
- [x] 5.2 Criar card responsivo com Carregar plantas, Ocorrências e Inspeções salvas acima da navegação; verificar disposição, ações, estados de progresso/vazio/erro e alvos de toque em 320, 768 e 1024 unidades lógicas.
- [x] 5.3 Criar modal do catálogo por `name` com emissão exclusiva de `code` ao selecionar; verificar saída capturada, fechamento e ausência de mutação ou filtro de plantas.
- [x] 5.4 Criar editor com indicadores circulares independentes, semântica de multisseleção, lista rolável e rodapé fixo Atualizar com contagem de plantas; verificar marcação/desmarcação, persistência ao fechar, falha local e botão visível com lista extensa/texto ampliado.
- [x] 5.5 Criar modal de inspeções locais com estados, datas, contagens, retomada e ação explícita de sincronização; verificar listagem offline de todos os estados, vazio e retry sem excluir registros sincronizados.

## 6. Verificação integrada e documentação

- [x] 6.1 Atualizar testes que esperam o placeholder e adicionar regressões para navegação, carregamento filtrado, edição de duas plantas e finalização única; verificar suíte de widgets sem acesso a serviços reais.
- [x] 6.2 Executar testes de persistência e sincronização que cubram reinício, add/remove/add, ausência de GPS, resposta perdida, lote posterior pendente e falha de gravação; verificar IDs e diário preservados, usando SQLite real temporário e transporte remoto controlado.
- [x] 6.3 Validar o fluxo completo em dispositivo/emulador e em ambiente remoto de teste autorizado: carregar, editar duas plantas, finalizar offline, reiniciar e reenviar; verificar uma operação, dois vínculos e eventos/estado coerentes nas quatro tabelas, sem repetir ao reenviar.
- [x] 6.4 Executar formatação, análise estática e testes Flutter apropriados, além de revisar telas em paisagem curta e texto ampliado; registrar resultados e resolver regressões introduzidas.
- [x] 6.5 Documentar o contrato efetivamente verificado e qualquer nova RPC, identificar a versão legada divergente em `database.md` e registrar limitações de mapas offline/acesso remoto; verificar coerência com os artefatos e executar `openspec validate implement-manual-inspection --strict`.

