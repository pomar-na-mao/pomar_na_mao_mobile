import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late MipdDatabase database;
  late MipdLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mipd_store_test_');
    database = MipdDatabase(
      projectUrl: 'https://mipd-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    store = MipdLocalStore(
      database,
      newId: () => 'local-1',
      clock: () => DateTime.utc(2026, 10, 21, 12),
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('persists, lists and reconciles a marking', () async {
    final created = await store.create(
      plantId: 'plant-1',
      occurrenceTypeId: 'pest-1',
      plantParts: const {MipdPlantPart.leaf, MipdPlantPart.fruit},
      localPhotoPath: 'photo.jpg',
    );
    expect(created.localId, 'local-1');
    expect(await store.listSyncable(), hasLength(1));

    await store.markSyncing(['local-1']);
    expect((await store.find('local-1'))!.status, MipdSyncStatus.syncing);
    await store.setRemotePhotoPath('local-1', 'user/device/local-1.jpg');
    await store.markSynced(
      MipdSyncResult(
        localMarkingId: 'local-1',
        operationId: 'operation-1',
        occurrenceId: 'occurrence-1',
        markingId: 'marking-1',
        syncedAt: DateTime.utc(2026, 10, 21, 13),
      ),
    );

    final synced = (await store.list()).single;
    expect(synced.status, MipdSyncStatus.synced);
    expect(synced.remotePhotoPath, 'user/device/local-1.jpg');
    expect(synced.remoteOperationId, 'operation-1');
  });

  test('recovers syncing item as pending after reopening', () async {
    await store.create(
      plantId: 'plant-1',
      occurrenceTypeId: 'pest-1',
      plantParts: const {MipdPlantPart.root},
    );
    await store.markSyncing(['local-1']);
    final deviceId = await store.deviceId;
    await database.close();

    database = MipdDatabase(
      projectUrl: 'https://mipd-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    store = MipdLocalStore(database);

    expect(await store.deviceId, deviceId);
    expect((await store.list()).single.status, MipdSyncStatus.pending);
  });
}
