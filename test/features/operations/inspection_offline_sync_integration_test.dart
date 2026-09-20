import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledRemoteDataSource implements InspectionRemoteDataSource {
  int attempts = 0;
  List<Map<String, dynamic>> receivedPayloads = [];
  bool shouldFailOnNetwork = false;
  bool shouldSimulateLostResponse = false;

  final Set<String> registeredOperationIds = {};

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async => const [
        OccurrenceType(id: 'type-1', name: 'Praga', code: 'pest'),
        OccurrenceType(id: 'type-2', name: 'Seca', code: 'drought'),
      ];

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async => [
        InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1, description: 'Planta 1'),
        InspectionPlant(id: 'p-2', latitude: -23.2, longitude: -46.2, description: 'Planta 2'),
      ];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async =>
      {};

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async {
    final types = await fetchOccurrenceTypes();
    final plants = await fetchPlants();
    return InspectionSnapshot(plants: plants, types: types, loadedAt: DateTime.now().toUtc());
  }

  @override
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload) async {
    attempts++;
    receivedPayloads.add(payload);

    if (shouldFailOnNetwork) {
      throw Exception('Falha de conexão com a rede');
    }

    final localInspectionId = payload['localInspectionId'] as String;
    registeredOperationIds.add(localInspectionId);

    if (shouldSimulateLostResponse) {
      // The server commits, but network drops before client receives the answer
      shouldSimulateLostResponse = false;
      throw Exception('Timeout ao aguardar resposta do servidor');
    }

    return const InspectionSyncResult(
      operationId: 'server-op-42',
      created: 1,
      updated: 0,
      resolved: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final ffiFactory = databaseFactoryFfi;

  late Directory tempDir;
  late InspectionDatabase db;
  late InspectionLocalStore store;
  late ControlledRemoteDataSource remote;
  late DefaultInspectionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_sync_integration_');
    db = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );
    store = InspectionLocalStore(db);
    remote = ControlledRemoteDataSource();
    repo = DefaultInspectionRepository(localStore: store, remoteDataSource: remote);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('offline sync flow: load, add/remove/add sequence, restart recovery, lost response retry', () async {
    // 1. Initial snapshot load
    final snapshot = await repo.loadSnapshot();
    expect(snapshot, isNotNull);
    expect(snapshot!.plants.length, 2);

    // 2. Add/Remove/Add sequence on plant 1 without GPS (null location)
    await repo.togglePlantOccurrence('p-1', 'type-1', location: null);
    await repo.togglePlantOccurrence('p-1', 'type-1', location: null);
    await repo.togglePlantOccurrence('p-1', 'type-1', location: null);

    // Toggle plant 2
    await repo.togglePlantOccurrence('p-2', 'type-2', location: null);

    // Verify draft has 2 changed plants and 4 changes
    var inspections = await repo.listLocalInspections();
    expect(inspections.length, 1);
    final draft = inspections.single;
    expect(draft.isDraft, isTrue);
    expect(draft.plantsCount, 2);
    expect(draft.changesCount, 4);

    // 3. Simulate App Restart: close db and reopen new instance
    await db.close();

    final reopenedDb = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );
    final reopenedStore = InspectionLocalStore(reopenedDb);
    final reopenedRepo = DefaultInspectionRepository(
      localStore: reopenedStore,
      remoteDataSource: remote,
    );

    // Verify draft and changes are completely recovered
    inspections = await reopenedRepo.listLocalInspections();
    expect(inspections.length, 1);
    expect(inspections.single.id, draft.id);
    expect(inspections.single.plantsCount, 2);
    expect(inspections.single.changesCount, 4);

    // 4. Finalize inspection
    final finalized = await reopenedRepo.finalizeInspection();
    expect(finalized, isNotNull);
    expect(finalized!.isDraft, isFalse);

    // 5. Lost response scenario: Remote commits but client loses response
    remote.shouldSimulateLostResponse = true;
    var synced = await reopenedRepo.syncPending();
    expect(synced, isFalse);

    var currentStatus = (await reopenedRepo.listLocalInspections()).first.status;
    expect(currentStatus, InspectionSyncStatus.error);

    // Retry synchronization with exact same payload and identifiers
    synced = await reopenedRepo.syncPending();
    expect(synced, isTrue);

    currentStatus = (await reopenedRepo.listLocalInspections()).first.status;
    expect(currentStatus, InspectionSyncStatus.synced);
    expect((await reopenedRepo.listLocalInspections()).first.remoteId, 'server-op-42');

    // Payloads reused the exact same localInspectionId
    expect(remote.receivedPayloads[0]['localInspectionId'], remote.receivedPayloads[1]['localInspectionId']);

    await reopenedDb.close();
  });
}
