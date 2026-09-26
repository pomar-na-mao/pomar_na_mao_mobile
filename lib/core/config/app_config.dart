import 'tenant_config.dart';

abstract final class AppConfig {
  /// Identificador do tenant informado via `--dart-define=TENANT=...`
  static const tenantId = String.fromEnvironment(
    'TENANT',
    defaultValue: 'ricardoLichia',
  );

  /// Configuração do tenant ativo resolvido para a aplicação.
  static final TenantConfig activeTenant = _resolveTenant();

  static TenantConfig _resolveTenant() {
    final baseTenant = TenantConfig.byId(tenantId);
    const customUrl = String.fromEnvironment('SUPABASE_URL');
    const customKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

    final resolvedUrl = customUrl.isNotEmpty
        ? customUrl
        : (baseTenant.supabaseUrl.isNotEmpty
            ? baseTenant.supabaseUrl
            : 'https://uxschjkypkkzprbwuhxm.supabase.co');

    final resolvedKey = customKey.isNotEmpty
        ? customKey
        : (baseTenant.supabasePublishableKey.isNotEmpty
            ? baseTenant.supabasePublishableKey
            : 'sb_publishable_idzivuZYu4ScWTOb14EtQA_VToCjySh');

    return TenantConfig(
      id: baseTenant.id,
      name: baseTenant.name,
      supabaseUrl: resolvedUrl,
      supabasePublishableKey: resolvedKey,
      propertyProfile: baseTenant.propertyProfile,
      fruitAssetPath: baseTenant.fruitAssetPath,
    );
  }

  /// URL da instância Supabase do cliente ativo.
  static String get supabaseUrl => activeTenant.supabaseUrl;

  /// Chave pública de publicação do Supabase do cliente ativo.
  static String get supabasePublishableKey =>
      activeTenant.supabasePublishableKey;
}
