import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/orchard_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final count in OrchardFixture.sizes) {
    test('fixture $count persists complete data and pending work', () async {
      final directory = await Directory.systemTemp.createTemp(
        'orchard_fixture_',
      );
      InspectionDatabase open() => InspectionDatabase(
        projectUrl: 'https://orchard-fixture.invalid',
        directory: directory.path,
        factory: databaseFactoryFfi,
      );
      var database = open();
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final fixture = OrchardFixture(count);
      var store = InspectionLocalStore(
        database,
        clock: () => OrchardFixture.loadedAt,
      );
      final pending = await fixture.seed(store);
      await database.close();
      database = open();
      store = InspectionLocalStore(database);

      final rows = (await store.readSharedPlantRows())!;
      expect(rows, hasLength(count));
      expect(rows.map((row) => row['id']).toSet(), hasLength(count));
      expect(
        rows.where((row) => row['non_existent'] == true),
        hasLength(count ~/ 10),
      );
      expect(
        rows.map(InspectionPlant.fromJson).where((p) => !p.hasValidCoordinates),
        hasLength(count ~/ 101),
      );
      expect(await store.readZoneRows(), hasLength(OrchardFixture.zoneCount));
      expect(await store.readCatalog(), hasLength(2));
      final zoneIds = fixture.zones.map((zone) => zone['id']).toSet();
      expect(rows.every((row) => zoneIds.contains(row['zone_id'])), isTrue);
      if (count == 0) {
        expect(pending, isNull);
        final draft = (await store.list()).single;
        expect(draft.isDraft, isTrue);
        expect(draft.changesCount, 0);
      } else {
        final restored = (await store.list()).singleWhere(
          (item) => item.id == pending!.id,
        );
        expect(restored.status, InspectionSyncStatus.pending);
        expect(restored.changesCount, 1);
        expect(restored.payload, pending!.payload);
        expect((await store.changes(restored.id)).single.typeId, 'drought');
        expect(InspectionPlant.fromJson(rows.first).openTypeIds, {
          'pest',
          'drought',
        });
      }
    });
  }

  for (final distribution in OrchardDistribution.values) {
    test('$distribution is deterministic with complete identifiers', () {
      final first = OrchardFixture(21000, distribution: distribution);
      final second = OrchardFixture(21000, distribution: distribution);
      expect(
        first.plants.map((p) => p.toJson()).toList(),
        second.plants.map((p) => p.toJson()).toList(),
      );
      final coordinates = first.plants
          .where((p) => p.hasValidCoordinates)
          .map((p) => (p.latitude, p.longitude))
          .toSet();
      if (distribution == OrchardDistribution.coincident) {
        expect(coordinates, hasLength(1));
      } else {
        expect(coordinates.length, greaterThan(1000));
      }
    });
  }
}
