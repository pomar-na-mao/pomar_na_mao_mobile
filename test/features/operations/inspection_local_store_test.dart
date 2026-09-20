import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final ffiFactory = databaseFactoryFfi;

  late Directory tempDir;
  late InspectionDatabase db;
  late InspectionLocalStore store;
  var currentTime = DateTime.utc(2026, 9, 18, 20, 0, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspection_store_test_');
    db = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );
    store = InspectionLocalStore(db, clock: () => currentTime);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  final sampleTypes = [
    const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest'),
    const OccurrenceType(id: 't-2', name: 'Seca', code: 'drought'),
  ];

  final samplePlants = [
    InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1, description: 'Planta 1'),
    InspectionPlant(id: 'p-2', latitude: -23.2, longitude: -46.2, description: 'Planta 2'),
    InspectionPlant(id: 'p-3', latitude: -23.3, longitude: -46.3, description: 'Planta 3'),
  ];

  test('replaceSnapshot persists plants and catalog, creates active draft', () async {
    final snapshot = InspectionSnapshot(
      plants: samplePlants,
      types: sampleTypes,
      loadedAt: currentTime,
    );

    await store.replaceSnapshot(snapshot);

    final read = await store.readSnapshot();
    expect(read, isNotNull);
    expect(read!.plants.length, 3);
    expect(read.types.length, 2);

    final catalog = await store.readCatalog();
    expect(catalog.length, 2);

    final inspections = await store.list();
    expect(inspections.length, 1);
    expect(inspections.single.isDraft, isTrue);
    expect(inspections.single.plantsCount, 0);
  });

  test('toggle records changes in strict sequence even with freeze clock', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );

    // Freeze clock: same timestamp
    await store.toggle('p-1', 't-1');
    await store.toggle('p-1', 't-2');
    await store.toggle('p-1', 't-1'); // Remove t-1

    final draft = (await store.list()).single;
    expect(draft.changesCount, 3);
    expect(draft.plantsCount, 1);

    final changes = await store.changes(draft.id);
    expect(changes.length, 3);
    expect(changes[0].sequence, 1);
    expect(changes[1].sequence, 2);
    expect(changes[2].sequence, 3);
    expect(changes[0].added, isTrue);
    expect(changes[1].added, isTrue);
    expect(changes[2].added, isFalse);

    // Timestamps must be strictly increasing
    expect(changes[1].changedAt.isAfter(changes[0].changedAt), isTrue);
    expect(changes[2].changedAt.isAfter(changes[1].changedAt), isTrue);

    // Current plant state should have t-2 but not t-1
    final plants = (await store.readSnapshot())!.plants;
    final p1 = plants.firstWhere((p) => p.id == 'p-1');
    expect(p1.openTypeIds, {'t-2'});
  });

  test('toggle fails and rolls back if plant is unknown', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );

    expect(
      () => store.toggle('unknown-plant', 't-1'),
      throwsA(isA<StateError>()),
    );

    final draft = (await store.list()).single;
    expect(draft.changesCount, 0);
  });

  test('finalize groups only changed plants and locks payload', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );

    // Change p-1 and p-2; p-3 is untouched
    await store.toggle('p-1', 't-1');
    await store.toggle('p-2', 't-2');

    final finalized = await store.finalize();
    expect(finalized, isNotNull);
    expect(finalized!.isDraft, isFalse);
    expect(finalized.status, InspectionSyncStatus.pending);
    expect(finalized.plantsCount, 2);
    expect(finalized.changesCount, 2);

    final payload = finalized.payload;
    expect(payload['localInspectionId'], finalized.id);
    expect(payload['deviceId'], isNotEmpty);
    final plantsChanged = (payload['plantsChanged'] as List).cast<Map<String, dynamic>>();
    expect(plantsChanged.length, 2);
    final changedPlantIds = plantsChanged.map((p) => p['plantId']).toSet();
    expect(changedPlantIds, {'p-1', 'p-2'});
    expect(changedPlantIds.contains('p-3'), isFalse);

    // Editing after finalize starts a new draft
    await store.toggle('p-3', 't-1');
    final inspections = await store.list();
    expect(inspections.length, 2);
    expect(inspections.first.isDraft, isTrue);
    expect(inspections.first.id, isNot(equals(finalized.id)));
  });

  test('acknowledge marks inspection and changes as synced', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );
    await store.toggle('p-1', 't-1');
    final finalized = (await store.finalize())!;

    await store.markSyncing(finalized.id);
    var current = (await store.list()).firstWhere((i) => i.id == finalized.id);
    expect(current.status, InspectionSyncStatus.syncing);

    await store.acknowledge(
      finalized.id,
      const InspectionSyncResult(
        operationId: 'remote-op-999',
        created: 1,
        updated: 0,
        resolved: 0,
      ),
    );

    current = (await store.list()).firstWhere((i) => i.id == finalized.id);
    expect(current.status, InspectionSyncStatus.synced);
    expect(current.remoteId, 'remote-op-999');
    expect(current.syncedAt, isNotNull);

    final pendingList = await store.pending();
    expect(pendingList, isEmpty);
  });

  test('markError with network error marks status as pending and message as Sem internet', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );
    await store.toggle('p-1', 't-1');
    final finalized = (await store.finalize())!;

    await store.markError(finalized.id, 'SocketException: Failed host lookup: supabase.co');
    final current = (await store.list()).firstWhere((i) => i.id == finalized.id);
    expect(current.status, InspectionSyncStatus.pending);
    expect(current.error, 'Sem internet');
    expect(current.displayErrorMessage, 'Sem internet');

    // Verify it is still picked up by pending() for future retry
    final pendingList = await store.pending();
    expect(pendingList.map((i) => i.id), contains(finalized.id));
  });

  test('removePlantFromInspection updates inspection counts and deletes inspection when last plant is removed', () async {
    await store.replaceSnapshot(
      InspectionSnapshot(plants: samplePlants, types: sampleTypes, loadedAt: currentTime),
    );
    await store.toggle('p-1', 't-1');
    await store.toggle('p-2', 't-2');

    final finalized = (await store.finalize())!;
    expect(finalized.plantsCount, 2);
    expect(finalized.changesCount, 2);

    // Remove plant p-1 from finalized inspection
    await store.removePlantFromInspection(finalized.id, 'p-1');

    var list = await store.list();
    expect(list.length, 1);
    final updated = list.single;
    expect(updated.id, finalized.id);
    expect(updated.plantsCount, 1);
    expect(updated.changesCount, 1);

    final remainingChanges = await store.changes(finalized.id);
    expect(remainingChanges.length, 1);
    expect(remainingChanges.single.plantId, 'p-2');

    // Remove last plant p-2 -> inspection should be completely removed from database
    await store.removePlantFromInspection(finalized.id, 'p-2');

    list = await store.list();
    expect(list, isEmpty);

    final finalChanges = await store.changes(finalized.id);
    expect(finalChanges, isEmpty);
  });
}
