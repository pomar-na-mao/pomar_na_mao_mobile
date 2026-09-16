import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/inventory/data/supabase_inventory_repository.dart';

void main() {
  test(
    'queries existing and available totals with the boolean filters',
    () async {
      final filters = <bool>[];
      final repository = SupabaseInventoryRepository.withCountQuery((
        value,
      ) async {
        filters.add(value);
        return value ? 7 : 12345;
      });

      final summary = await repository.fetchSummary();

      expect(filters, containsAll(<bool>[false, true]));
      expect(filters.length, 2);
      expect(summary.existingPlants, 12345);
      expect(summary.availablePlantingSpots, 7);
    },
  );

  test('keeps zero as a valid category total', () async {
    final repository = SupabaseInventoryRepository.withCountQuery(
      (_) async => 0,
    );

    final summary = await repository.fetchSummary();

    expect(summary.existingPlants, 0);
    expect(summary.availablePlantingSpots, 0);
  });
}
