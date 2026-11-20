import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/harvest_forecast_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late HarvestForecastDatabase database;
  late HarvestForecastLocalStore store;
  var idCounter = 0;

  setUp(() async {
    idCounter = 0;
    tempDir = await Directory.systemTemp.createTemp(
      'harvest_forecast_store_test_',
    );
    database = HarvestForecastDatabase(
      projectUrl: 'https://harvest-forecast-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    store = HarvestForecastLocalStore(
      database,
      newId: () => 'local-${++idCounter}',
      clock: () => DateTime.utc(2026, 11, 19, 10, 0, idCounter),
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('lists markings from newest to oldest (top of list)', () async {
    await store.create(
      latitude: -23.1,
      longitude: -46.1,
      classification: HarvestForecastClassification.p,
      createdAt: DateTime.utc(2026, 11, 19, 10, 0, 0),
    );
    await store.create(
      latitude: -23.2,
      longitude: -46.2,
      classification: HarvestForecastClassification.gg,
      createdAt: DateTime.utc(2026, 11, 19, 10, 5, 0),
    );

    final list = await store.list();
    expect(list.map((m) => m.localId), ['local-2', 'local-1']);
    expect(list.first.classification, HarvestForecastClassification.gg);
  });

  test('updates classification, resets sync status and deletes marking', () async {
    final created = await store.create(
      latitude: -23.1,
      longitude: -46.1,
      classification: HarvestForecastClassification.n,
    );
    await store.markSynced(
      HarvestForecastSyncResult(
        localMarkingId: created.localId,
        id: 'remote-1',
        plantId: 'plant-1',
        zoneId: 'zone-1',
        syncedAt: DateTime.utc(2026, 11, 19, 11),
      ),
    );
    expect(
      (await store.find(created.localId))!.status,
      HarvestForecastSyncStatus.synced,
    );

    final updated = await store.updateClassification(
      created.localId,
      HarvestForecastClassification.g,
    );
    expect(updated, isNotNull);
    expect(updated!.classification, HarvestForecastClassification.g);
    expect(updated.status, HarvestForecastSyncStatus.pending);

    final deleted = await store.delete(created.localId);
    expect(deleted, isTrue);
    expect(await store.list(), isEmpty);
  });

  test('recovers syncing item as pending after reopening', () async {
    await store.create(
      latitude: -23.1,
      longitude: -46.1,
      classification: HarvestForecastClassification.m,
    );
    await store.markSyncing(['local-1']);
    final deviceId = await store.deviceId;
    await database.close();

    database = HarvestForecastDatabase(
      projectUrl: 'https://harvest-forecast-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    store = HarvestForecastLocalStore(database);

    expect(await store.deviceId, deviceId);
    expect(
      (await store.list()).single.status,
      HarvestForecastSyncStatus.pending,
    );
  });
}
