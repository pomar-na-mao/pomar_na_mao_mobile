import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeInspectionRemoteDataSource implements InspectionRemoteDataSource {
  FakeInspectionRemoteDataSource({
    this.types = const [],
    this.plants = const [],
    this.openOccurrences = const {},
    this.syncResultBuilder,
  });

  List<OccurrenceType> types;
  List<InspectionPlant> plants;
  Map<String, Set<String>> openOccurrences;
  InspectionSyncResult Function(Map<String, dynamic> payload)? syncResultBuilder;

  int syncCallCount = 0;
  List<Map<String, dynamic>> syncedPayloads = [];
  bool throwOnSync = false;
  bool throwOnFetch = false;

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async {
    if (throwOnFetch) throw Exception('Remote network failure');
    return types;
  }

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async {
    if (throwOnFetch) throw Exception('Remote network failure');
    return plants;
  }

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async {
    if (throwOnFetch) throw Exception('Remote network failure');
    return openOccurrences;
  }

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async {
    if (throwOnFetch) throw Exception('Remote network failure');
    final resolved = plants.map((p) => p.withState(openOccurrences[p.id] ?? const {})).toList();
    return InspectionSnapshot(
      plants: resolved,
      types: types,
      loadedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload) async {
    syncCallCount++;
    syncedPayloads.add(payload);
    if (throwOnSync) throw const SocketException('Failed host lookup: sem conexao');
    if (syncResultBuilder != null) return syncResultBuilder!(payload);
    return const InspectionSyncResult(
      operationId: 'op-123',
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
  late FakeInspectionRemoteDataSource remote;
  late DefaultInspectionRepository repository;

  final sampleTypes = [
    const OccurrenceType(id: 't-1', name: 'Lagarta', code: 'caterpillar'),
    const OccurrenceType(id: 't-2', name: 'Pulgão', code: 'aphid'),
  ];
  final samplePlants = [
    InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1, description: 'P1'),
    InspectionPlant(id: 'p-2', latitude: -23.2, longitude: -46.2, description: 'P2'),
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspection_repo_test_');
    db = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );
    store = InspectionLocalStore(db);
    remote = FakeInspectionRemoteDataSource(
      types: sampleTypes,
      plants: samplePlants,
      openOccurrences: {
        'p-1': {'t-1'},
      },
    );
    repository = DefaultInspectionRepository(
      localStore: store,
      remoteDataSource: remote,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loadSnapshot fetches remote and replaces local cache when no local cache exists', () async {
    final snapshot = await repository.loadSnapshot();
    expect(snapshot, isNotNull);
    expect(snapshot!.plants.length, 2);
    expect(snapshot.types.length, 2);
    expect(snapshot.plants.first.openTypeIds, {'t-1'});

    // Subsequent call without forceRemote should read from local store
    remote.throwOnFetch = true;
    final cached = await repository.loadSnapshot();
    expect(cached, isNotNull);
    expect(cached!.plants.length, 2);
  });

  test('loadSnapshot falls back to local cache when remote fails', () async {
    // Prime local store
    await repository.loadSnapshot();

    // Now make remote fail and forceRemote = true
    remote.throwOnFetch = true;
    final fallback = await repository.loadSnapshot(forceRemote: true);
    expect(fallback, isNotNull);
    expect(fallback!.plants.length, 2);
  });

  test('loadSnapshot rethrows when remote fails and local is empty', () async {
    remote.throwOnFetch = true;
    expect(() => repository.loadSnapshot(), throwsA(isA<Exception>()));
  });

  test('syncPending merges multiple pending inspections into a single payload with all altered plants', () async {
    // Prime snapshot and create two distinct finalized inspections
    await repository.loadSnapshot();

    await store.toggle('p-1', 't-2');
    final first = (await store.finalize())!;

    await store.toggle('p-2', 't-1');
    final second = (await store.finalize())!;

    expect(first.id, isNot(equals(second.id)));

    // Set remote to fail on sync
    remote.throwOnSync = true;
    final success = await repository.syncPending();
    expect(success, isFalse);

    // One merged attempt was made containing both plants
    expect(remote.syncCallCount, 1);
    final payload = remote.syncedPayloads.single;
    final plantsChanged = (payload['plantsChanged'] as List).cast<Map<String, dynamic>>();
    expect(plantsChanged.length, 2);
    expect(plantsChanged.map((p) => p['plantId']).toSet(), {'p-1', 'p-2'});

    final inspections = await repository.listLocalInspections();
    final firstStatus = inspections.firstWhere((i) => i.id == first.id).status;
    final secondStatus = inspections.firstWhere((i) => i.id == second.id).status;

    expect(firstStatus, InspectionSyncStatus.pending);
    expect(secondStatus, InspectionSyncStatus.pending);

    // Now fix remote and sync again
    remote.throwOnSync = false;
    final retrySuccess = await repository.syncPending();
    expect(retrySuccess, isTrue);

    // Only 1 additional sync call was made (total 2)
    expect(remote.syncCallCount, 2);

    // Both inspections should now be marked as synced with the same remoteId
    final updated = await repository.listLocalInspections();
    final updatedFirst = updated.firstWhere((i) => i.id == first.id);
    final updatedSecond = updated.firstWhere((i) => i.id == second.id);
    expect(updatedFirst.status, InspectionSyncStatus.synced);
    expect(updatedSecond.status, InspectionSyncStatus.synced);
    expect(updatedFirst.remoteId, 'op-123');
    expect(updatedSecond.remoteId, 'op-123');
  });

  test('concurrent calls to syncPending reuse the same in-flight execution', () async {
    await repository.loadSnapshot();
    await store.toggle('p-1', 't-2');
    await store.finalize();

    final f1 = repository.syncPending();
    final f2 = repository.syncPending();

    final results = await Future.wait([f1, f2]);
    expect(results[0], isTrue);
    expect(results[1], isTrue);
    expect(remote.syncCallCount, 1);
  });
}
