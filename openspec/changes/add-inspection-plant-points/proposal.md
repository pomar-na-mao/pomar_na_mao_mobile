## Why

Durante a inspecao em campo, o operador precisa registrar rapidamente pontos do mapa que representam plantas novas ou posicoes disponiveis para plantio, sem misturar esse fluxo com alteracoes de ocorrencias de plantas ja cadastradas. Separar essa coleta e sincronizacao reduz risco de envio acidental junto das inspecoes e cria um contrato remoto proprio para inserir registros em `plants`.

## What Changes

- Permitir que a tela de Inspecao aceite toque longo em ponto livre do mapa para criar uma marcacao local de planta, gravando latitude, longitude, o estado `non_existent` e opcionalmente a zona (`zone_id`).
- Abrir um modal ao tocar e segurar no mapa para confirmar se a planta marcada deve ser sincronizada como inexistente ou existente e selecionar a zona correspondente (com selecao inicial herdada do filtro ativo de zona).
- Permitir remover uma planta adicionada localmente com duplo toque na marcacao/lista propria.
- Exibir uma lista separada de plantas adicionadas localmente, acessivel por botao proprio, independente da lista de inspecoes salvas, exibindo a zona quando informada.
- Adicionar uma acao de sincronizacao separada para as plantas adicionadas, sem reutilizar o botao ou a fila de sincronizacao de inspecoes.
- Criar uma nova RPC para inserir as plantas marcadas na tabela `plants`, usando defaults do banco para todos os campos exceto `latitude`, `longitude`, `non_existent` e `zone_id`.
- Atualizar `database.md` no detalhamento separado e no bloco de query unica com a nova RPC e suas permissoes.

## Capabilities

### New Capabilities
<!-- No new capability path. The behavior extends existing inspection and offline sync capabilities. -->

### Modified Capabilities
- `manual-inspection`: adiciona marcacao de novos pontos de planta no mapa, modal de confirmacao e lista separada de plantas adicionadas.
- `inspection-offline-sync`: adiciona persistencia local, fila, listagem e sincronizacao remota separada para plantas adicionadas via nova RPC.

## Impact

- UI Flutter da tela de Inspecao: mapa, botoes de acao, modal de confirmacao e lista de plantas adicionadas.
- Estado e persistencia local offline-first: modelos de plantas adicionadas, armazenamento SQLite, status de sincronizacao e retry.
- Repositorio/data source Supabase: chamada dedicada para a nova RPC, mantendo a sincronizacao de inspecoes intacta.
- Banco/documentacao: nova RPC documentada em `database.md`, incluindo o bloco consolidado de criacao de tabelas/RPCs/RLS.
- Testes: cobertura de view model/repositorio, persistencia local, composicao de payload e widgets do modal/lista.
