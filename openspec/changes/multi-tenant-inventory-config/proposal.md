## Why

Atualmente, as informações do card Visão da Propriedade e Configurações de Cultivo da tela de Inventário, assim como as credenciais do Supabase (`supabaseUrl` e `supabasePublishableKey`), estão fixas/hardcoded no código ou limitadas a uma única definição por compilação.
Para suportar múltiplos clientes/tenants em um mesmo código fonte e alternar facilmente entre eles via arquivos de configuração ou variáveis de ambiente/build flavors, é necessário tornar esses dados totalmente parametrizáveis e dinâmicos por cliente.

## What Changes

- **Configuração Multi-tenant de Inventário**:
  - Parametrização dos dados do card Visão da Propriedade (nome da fazenda/propriedade, área total, cultura principal, cultura/variedades, etc.).
  - Parametrização dos dados de Configuração de Cultivo (espaçamento, classificação, densidade de plantas/ha, variedade/cultivo, ícone/imagem da fruta).
- **Configuração Dinâmica do Supabase**:
  - Parametrização de `supabaseUrl` e `supabasePublishableKey` por cliente via `AppConfig` / arquivos de profile de tenant ou `--dart-define`.
- **Seleção/Alternância de Cliente**:
  - Mecanismo centralizado para carregar a configuração ativa do cliente (tenant) selecionado na inicialização do aplicativo e repassar para os repositórios e telas (inventário e Supabase).

## Capabilities

### New Capabilities

- `tenant-config`: Gerenciamento de configurações multi-tenant do projeto, permitindo parametrizar credenciais do Supabase (`supabaseUrl`, `supabasePublishableKey`) e perfis de propriedades/cultivos para a tela de Inventário por cliente.

### Modified Capabilities

(Nenhuma especificação anterior é violada; este é um novo modelo de parametrização multi-tenant).

## Impact

- `lib/core/config/app_config.dart`: Atualização da classe de configuração para suportar múltiplos perfis de clientes/tenants e leitura parametrizada.
- `lib/main.dart`: Inicialização dinâmica do client do Supabase e injeção de dependências com base no tenant ativo.
- `lib/features/inventory/domain/inventory_property_profile.dart`: Suporte a múltiplos perfis de cliente e carregamento parametrizado dos cards de Visão da Propriedade e Configurações de Cultivo.
- `lib/features/inventory/presentation/inventory_view.dart` e widgets de inventário: Consumo do perfil parametrizado do cliente ativo.
