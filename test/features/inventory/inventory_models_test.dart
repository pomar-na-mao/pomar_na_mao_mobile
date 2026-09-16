import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_property_profile.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';

void main() {
  test('inventory summary exposes both plant totals', () {
    const summary = InventorySummary(
      existingPlants: 21809,
      availablePlantingSpots: 2,
    );

    expect(summary.existingPlants, 21809);
    expect(summary.availablePlantingSpots, 2);
  });

  test('default property profile exposes the specified orchard data', () {
    const profile = InventoryPropertyProfile.sitioSaoFrancisco;

    expect(profile.farmName, 'Sítio São Francisco');
    expect(profile.totalArea, '54 ha');
    expect(profile.crop, 'Avocado');
    expect(profile.spacing, '7 × 7 m a 8 × 8 m');
    expect(profile.classification, 'Semi-adensado');
    expect(profile.density, '70 a 100 plantas/ha');
    expect(profile.variety, 'Hass');
  });
}
