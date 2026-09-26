import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_property_profile.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';

void main() {
  test('inventory summary exposes both plant totals', () {
    const summary = InventorySummary(
      existingPlants: 21809,
      availablePlantingSpots: 2,
      zones: 8,
      regionPoints: 434,
      farmBoundaryPoints: 18,
    );

    expect(summary.existingPlants, 21809);
    expect(summary.availablePlantingSpots, 2);
    expect(summary.zones, 8);
    expect(summary.regionPoints, 434);
    expect(summary.farmBoundaryPoints, 18);
  });

  test('default property profile exposes the specified orchard data', () {
    const profile = InventoryPropertyProfile.ricardoLichia;

    expect(profile.farmName, 'Fazenda Coatiara');
    expect(profile.totalArea, '117 ha');
    expect(profile.crop, 'Lichia');
    expect(profile.spacing, '8 × 5 m');
    expect(profile.classification, 'Semi-adensado');
    expect(profile.density, '187 plantas/ha');
    expect(profile.variety, 'Múltiplas');
  });
}
