import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/datasources/farm_remote_data_source.dart';

void main() {
  test('loads every plant page exactly once with inclusive ranges', () async {
    final ranges = <(int, int)>[];
    final rows = await fetchAllPlantPages((from, to) async {
      ranges.add((from, to));
      final count = from == 0
          ? 1000
          : from == 1000
          ? 1
          : 0;
      return List.generate(count, (index) => {'id': 'plant-${from + index}'});
    });

    expect(rows, hasLength(1001));
    expect(ranges, [(0, 999), (1000, 1999), (1001, 2000)]);
  });

  test('continues when the server returns fewer rows than requested', () async {
    final source = List.generate(250, (index) => {'id': 'plant-$index'});
    final ranges = <(int, int)>[];

    final rows = await fetchAllPlantPages((from, to) async {
      ranges.add((from, to));
      if (from >= source.length) return const [];
      final cappedTo = (from + 75).clamp(0, source.length);
      return source.sublist(from, cappedTo);
    });

    expect(rows, source);
    expect(ranges, [
      (0, 999),
      (75, 1074),
      (150, 1149),
      (225, 1224),
      (250, 1249),
    ]);
  });

  test('fails when a paged result repeats the stable row id', () async {
    expect(
      () => fetchAllPlantPages((from, to) async {
        if (from == 0) {
          return [
            {'id': 'plant-1'},
          ];
        }
        if (from == 1) {
          return [
            {'id': 'plant-1'},
          ];
        }
        return const [];
      }),
      throwsStateError,
    );
  });

  test('fails when a paged result does not expose a stable id', () async {
    expect(
      () => fetchAllPlantPages((from, to) async {
        if (from == 0) {
          return [
            {'description': 'Sem id'},
          ];
        }
        return const [];
      }),
      throwsStateError,
    );
  });

  test('propagates an intermediate page failure', () async {
    expect(
      () => fetchAllPlantPages((from, to) async {
        if (from == 0) {
          return [
            {'id': 'plant-1'},
          ];
        }
        throw StateError('remote page failed');
      }),
      throwsStateError,
    );
  });

  test('uses only the fields shared by farm, inventory, and inspection', () {
    expect(
      sharedPlantColumns,
      'id, latitude, longitude, description, zone_id, non_existent',
    );
  });
}
