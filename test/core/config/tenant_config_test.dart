import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/config/app_config.dart';
import 'package:pomar_na_mao_mobile/core/config/tenant_config.dart';

void main() {
  group('TenantConfig & AppConfig tests', () {
    test('ricardoLichia tenant returns correct property details and credentials', () {
      final tenant = TenantConfig.byId('ricardoLichia');
      expect(tenant.id, equals('ricardoLichia'));
      expect(tenant.name, equals('Ricardo Lichia'));
      expect(tenant.propertyProfile.farmName, equals('Fazenda Coatiara'));
      expect(tenant.propertyProfile.crop, equals('Lichia'));
      expect(tenant.propertyProfile.spacing, equals('8 × 5 m'));
      expect(tenant.propertyProfile.density, equals('187 plantas/ha'));
    });

    test('hassAvocado tenant returns correct property details and credentials', () {
      final tenant = TenantConfig.byId('hassAvocado');
      expect(tenant.id, equals('hassAvocado'));
      expect(tenant.name, equals('Hass Avocado'));
      expect(tenant.propertyProfile.farmName, equals('Fazenda Santa Maria'));
      expect(tenant.propertyProfile.crop, equals('Abacate Hass'));
      expect(tenant.propertyProfile.spacing, equals('6 × 4 m'));
      expect(tenant.propertyProfile.density, equals('416 plantas/ha'));
      expect(tenant.propertyProfile.variety, equals('Hass'));
    });

    test('unknown tenant falls back safely to ricardoLichia', () {
      final tenant = TenantConfig.byId('non_existent_tenant');
      expect(tenant.id, equals('ricardoLichia'));
    });

    test('AppConfig resolves activeTenant correctly', () {
      expect(AppConfig.activeTenant, isNotNull);
      expect(AppConfig.activeTenant.id, equals('ricardoLichia'));
    });
  });
}
