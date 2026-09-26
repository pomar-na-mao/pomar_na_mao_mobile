## Context

Atualmente, `AppConfig` possui credenciais estáticas (`SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`) e `InventoryPropertyProfile` contém a constante `sitioSaoFrancisco` hardcoded.
Para atender à necessidade de múltiplos clientes, o design deve permitir que tanto as credenciais do Supabase quanto os dados de propriedade e cultivo sejam selecionados dinamicamente via parâmetro de compilação/execução (`--dart-define=TENANT=...`) ou através de instâncias de configuração por cliente (`TenantConfig`).

Ver `proposal.md` para motivação e `specs/tenant-config/spec.md` para requisitos normativos.

## Goals / Non-Goals

**Goals:**
- Criar a estrutura de modelo e registro `TenantConfig` no `lib/core/config/` para centralizar credenciais e perfis por cliente.
- Permitir chaveamento de tenant via `String.fromEnvironment('TENANT')` ou `--dart-define`.
- Atualizar `AppConfig` para exportar a configuração do tenant ativo (`activeTenant`).
- Atualizar `main.dart` para inicializar o `SupabaseClient` com as credenciais do tenant ativo.
- Atualizar o fluxo do inventário (`InventoryPropertyProfile`, `InventoryViewModel`, `InventoryView`) para carregar o perfil do cliente ativo em vez da constante estática.

**Non-Goals:**
- Criar um seletor visual na interface para o usuário final trocar de cliente em tempo de execução (a alternância é por build/instância de cliente/configuração do projeto).
- Alterar o esquema de tabelas do banco de dados no Supabase.

## Decisions

### Decisão 1: Modelo `TenantConfig` e Registro Centralizado

Criar uma classe `TenantConfig` contendo:
- `id`: identificador do cliente (ex: `'sitio_sao_francisco'`, `'fazenda_boavista'`, etc.)
- `name`: nome de exibição do cliente
- `supabaseUrl`: URL da instância Supabase do cliente
- `supabasePublishableKey`: Chave pública do Supabase do cliente
- `propertyProfile`: Instância de `InventoryPropertyProfile` (nome da fazenda, área total, cultura, espaçamento, classificação, densidade, variedade, asset do fruto)

**Alternativa considerada:** Ler apenas de variáveis de ambiente soltas sem estrutura orientada a objetos. Rejeitado porque a estrutura de classe facilita testes, injeção de dependências e adição de novos clientes de forma organizada.

### Decisão 2: Seleção de Tenant via `AppConfig`

Em `AppConfig`:
- Declarar o tenant padrão via `String.fromEnvironment('TENANT', defaultValue: 'sitio_sao_francisco')`.
- Manter suporte a overrides diretos de `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` para compatibilidade com CI/CD.
- Fornecer o getter estático `AppConfig.activeTenant` que resolve o `TenantConfig` correspondente.

### Decisão 3: Injeção do `InventoryPropertyProfile` no Inventário

`InventoryViewModel` passará a receber o `InventoryPropertyProfile` (padrão `AppConfig.activeTenant.propertyProfile`) ou obter do repositório/configuração, garantindo testabilidade e separação de conceitos.

## Risks / Trade-offs

- [Risk] Falha ao passar um `TENANT` inexistente via `--dart-define` → *Mitigação*: Fallback seguro para o tenant padrão (`sitio_sao_francisco`) com log de aviso no console.
- [Risk] Alteração de chave do Supabase inválida para um tenant → *Mitigação*: Suporte a variáveis `--dart-define=SUPABASE_URL=...` especificando override quando necessário.

## Migration Plan

1. Criar `lib/core/config/tenant_config.dart` com as definições de modelo e catálogo de clientes.
2. Atualizar `lib/core/config/app_config.dart` para expor o tenant ativo.
3. Atualizar `lib/main.dart` para usar `AppConfig.activeTenant.supabaseUrl` e `AppConfig.activeTenant.supabasePublishableKey`.
4. Atualizar `lib/features/inventory/domain/inventory_property_profile.dart` e `InventoryViewModel` para utilizar o perfil parametrizado.
5. Executar testes de unidade e verificação estática (`dart analyze`).
