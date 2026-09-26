import '../../features/inventory/domain/inventory_property_profile.dart';

/// Configuração de tenant/cliente do aplicativo.
///
/// Permite parametrizar credenciais de conexão ao Supabase e dados
/// de propriedade e cultivo para a tela de inventário.
class TenantConfig {
  const TenantConfig({
    required this.id,
    required this.name,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.propertyProfile,
    this.fruitAssetPath = 'assets/images/lichia.png',
  });

  final String id;
  final String name;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final InventoryPropertyProfile propertyProfile;
  final String fruitAssetPath;

  /// Cliente Ricardo Lichia
  static const ricardoLichia = TenantConfig(
    id: 'ricardoLichia',
    name: 'Ricardo Lichia',
    supabaseUrl: String.fromEnvironment('SUPABASE_URL_RICARDO'),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY_RICARDO',
    ),
    propertyProfile: InventoryPropertyProfile(
      farmName: 'Fazenda Coatiara',
      totalArea: '117 ha',
      crop: 'Lichia',
      spacing: '8 × 5 m',
      classification: 'Semi-adensado',
      density: '187 plantas/ha',
      variety: 'Múltiplas',
    ),
    fruitAssetPath: 'assets/images/lichia.png',
  );

  /// Cliente Hass Avocado
  static const hassAvocado = TenantConfig(
    id: 'hassAvocado',
    name: 'Hass Avocado',
    supabaseUrl: String.fromEnvironment('SUPABASE_URL_HASS'),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY_HASS',
    ),
    propertyProfile: InventoryPropertyProfile(
      farmName: 'Fazenda Santa Maria',
      totalArea: '85 ha',
      crop: 'Abacate Hass',
      spacing: '6 × 4 m',
      classification: 'Adensado',
      density: '416 plantas/ha',
      variety: 'Hass',
    ),
    fruitAssetPath: 'assets/images/avocado.png',
  );

  /// Os dois únicos tenants/clientes suportados no sistema.
  static const Map<String, TenantConfig> registeredTenants = {
    'ricardoLichia': ricardoLichia,
    'hassAvocado': hassAvocado,
  };

  /// Retorna o [TenantConfig] correspondente aos tenants suportados ('hassAvocado' ou 'ricardoLichia').
  static TenantConfig byId(String? id) {
    if (id == 'hassAvocado' ||
        id?.toLowerCase() == 'hass_avocado' ||
        id?.toLowerCase() == 'hassavocado') {
      return hassAvocado;
    }
    return ricardoLichia;
  }
}
