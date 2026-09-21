import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/datasources/farm_remote_data_source.dart';

void main() {
  test('loads every plant page exactly once with inclusive ranges', () async {
    final ranges = <(int, int)>[];
    final rows = await fetchAllPlantPages((from, to) async {
      ranges.add((from, to));
      final count = from == 0 ? 1000 : 1;
      return List.generate(count, (index) => {'id': 'plant-${from + index}'});
    });

    expect(rows, hasLength(1001));
    expect(ranges, [(0, 999), (1000, 1999)]);
  });

  test('uses only the fields shared by farm, inventory, and inspection', () {
    expect(
      sharedPlantColumns,
      'id, latitude, longitude, description, zone_id, non_existent',
    );
  });
}
