## 1. Configuração Multi-tenant Core

- [x] 1.1 Criar o modelo `TenantConfig` em `lib/core/config/tenant_config.dart` contendo credenciais Supabase e `InventoryPropertyProfile`, registrando os perfis iniciais dos clientes e verificando a compilação com `dart analyze`.
- [x] 1.2 Atualizar `lib/core/config/app_config.dart` para resolver dinamicamente o `TenantConfig` ativo via `--dart-define=TENANT=...` com fallback para `sitio_sao_francisco` e verificar a resolução via teste unitário.

## 2. Integração com Inicialização e Supabase

- [x] 2.1 Atualizar `lib/main.dart` para instanciar `SupabaseClient` usando `AppConfig.activeTenant.supabaseUrl` e `AppConfig.activeTenant.supabasePublishableKey`, e verificar que a inicialização do app carrega sem erros de runtime.

## 3. Parametrização do Inventário

- [x] 3.1 Atualizar `lib/features/inventory/domain/inventory_property_profile.dart` para aceitar perfis customizados por cliente e registrar os perfis no catálogo de tenants.
- [x] 3.2 Atualizar `InventoryViewModel` e `InventoryView` em `lib/features/inventory/presentation/` para receber e exibir o `InventoryPropertyProfile` do cliente ativo, verificando que os cards Visão da Propriedade e Configurações de Cultivo exibem os dados parametrizados corretamente.

## 4. Testes e Validação

- [x] 4.1 Adicionar/atualizar testes de unidade para `TenantConfig`, `AppConfig` e `InventoryViewModel` para validar a alternância de clientes e verificar a execução de `flutter test`.
- [x] 4.2 Executar `dart analyze` em todo o projeto para garantir ausência de avisos ou erros estáticos.
