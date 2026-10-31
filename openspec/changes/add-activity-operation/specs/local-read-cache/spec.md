## ADDED Requirements

### Requirement: Disponibilizar o catálogo de máquinas offline por projeto

O aplicativo SHALL manter um cache persistente de `public.machines`, isolado pela URL do projeto Supabase. A revisão SHALL preservar os campos de apresentação necessários ao seletor e permanecer disponível após reinício.

#### Scenario: Atualizar o catálogo de máquinas
- **WHEN** o usuário aciona Carregar dados na Atividade
- **THEN** todas as páginas de máquinas são validadas e publicadas atomicamente com plantas e caldas

#### Scenario: Abrir offline
- **WHEN** existe uma revisão local íntegra e o dispositivo está sem rede
- **THEN** o seletor disponibiliza as máquinas armazenadas sem leitura remota

### Requirement: Disponibilizar o catálogo de caldas offline por projeto

O aplicativo SHALL manter um cache persistente das caldas ativas de `public.mixtures` e suas composições de `public.mixture_inputs`, isolado pela URL do projeto Supabase. Cada composição SHALL incluir os dados de apresentação do respectivo `public.inputs`. Uma revisão local íntegra SHALL permanecer disponível após navegação e reinício.

#### Scenario: Inicializar o catálogo de caldas
- **WHEN** a Atividade solicita caldas e ainda não existe uma revisão local utilizável
- **THEN** o aplicativo busca todas as páginas de caldas ativas com suas composições, valida e publica o conjunto completo para seleção

#### Scenario: Reutilizar catálogo persistido
- **WHEN** o catálogo já foi inicializado e o usuário reabre a Atividade
- **THEN** o aplicativo fornece a revisão local sem exigir uma nova leitura remota

#### Scenario: Trocar o projeto configurado
- **WHEN** a URL do projeto Supabase muda
- **THEN** o aplicativo não apresenta caldas persistidas para o projeto anterior como pertencentes ao projeto atual

### Requirement: Atualizar plantas, caldas e máquinas de forma coordenada

A ação explícita de carregar dados na Atividade SHALL usar a rotina compartilhada de atualização para plantas e dados cartográficos e SHALL incluir os catálogos de caldas e máquinas. A nova revisão SHALL ser publicada somente quando todos os conjuntos obrigatórios estiverem completos e válidos.

#### Scenario: Atualizar com sucesso
- **WHEN** o usuário aciona Carregar dados e todas as leituras terminam com sucesso
- **THEN** o sistema publica revisões completas de plantas, caldas e máquinas e os consumidores passam a usá-las sem consultas remotas próprias

#### Scenario: Falhar durante a atualização
- **WHEN** qualquer página de plantas, caldas ou máquinas falha e existem revisões anteriores
- **THEN** o aplicativo mantém as últimas revisões íntegras, informa uma falha recuperável e não publica dados parciais

#### Scenario: Atualizar com lançamentos pendentes
- **WHEN** o catálogo muda enquanto existem lançamentos da Atividade ainda não sincronizados
- **THEN** os snapshots da calda e de sua composição permanecem inalterados e disponíveis para sincronização
