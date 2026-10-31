import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/data/shared_read_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/datasources/farm_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late ActivityDatabase fieldDatabase;
  late InspectionDatabase inspectionDatabase;
  late ActivityLocalStore localStore;
  late _FieldRemote remote;
  late SharedReadRepository shared;
  late DefaultActivityRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('field_repo_test_');
    fieldDatabase = ActivityDatabase(
      projectUrl: 'https://project.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inspectionDatabase = InspectionDatabase(
      projectUrl: 'https://project.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    var sequence = 0;
    localStore = ActivityLocalStore(
      fieldDatabase,
      newId: () => 'local-${sequence++}',
    );
    remote = _FieldRemote();
    shared = SharedReadRepository(
      localStore: InspectionLocalStore(inspectionDatabase),
      farmRemoteDataSource: _FarmRemote(),
      inspectionRemoteDataSource: _InspectionRemote(),
      activityRemoteDataSource: remote,
    );
    repository = DefaultActivityRepository(
      localStore: localStore,
      remoteDataSource: remote,
      sharedReadRepository: shared,
    );
  });

  tearDown(() async {
    await shared.dispose();
    await fieldDatabase.close();
    await inspectionDatabase.close();
    await directory.delete(recursive: true);
  });

  test('transport failure stays retryable and later reconciles ids', () async {
    final entry = await _save(repository);
    remote.throwSync = true;
    expect(await repository.syncAll(), isFalse);
    expect(
      (await localStore.find(entry.localId))!.syncStatus,
      ActivitySyncStatus.error,
    );

    remote.throwSync = false;
    expect(await repository.syncAll(), isTrue);
    final synced = await localStore.find(entry.localId);
    expect(synced!.syncStatus, ActivitySyncStatus.synced);
    expect(synced.remoteFieldOperationId, 'operation-${entry.localId}');
    expect(synced.remoteEntryId, 'entry-${entry.localId}');
  });

  test('concurrent sync all calls share one remote execution', () async {
    final entry = await _save(repository);
    remote.completer = Completer<List<ActivitySyncResult>>();
    final first = repository.syncAll();
    final second = repository.syncAll();
    for (var attempt = 0; attempt < 20 && remote.syncCalls == 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(remote.syncCalls, 1);

    remote.completer!.complete([remote.result(entry.localId)]);
    expect(await Future.wait([first, second]), everyElement(isTrue));
    expect(remote.syncCalls, 1);
  });
}

Future<ActivityEntry> _save(ActivityRepository repository) => repository.save(
  geometry: ActivityGeometry(
    type: ActivityGeometryType.route,
    points: const [ActivityPoint(-21, -47), ActivityPoint(-21.01, -47.01)],
  ),
  activity: 'roçagem',
  performedAt: DateTime.utc(2026, 10, 30, 15, 30),
  responsible: 'João',
  inputs: const [],
);

class _FieldRemote implements ActivityRemoteDataSource {
  var throwSync = false;
  var syncCalls = 0;
  Completer<List<ActivitySyncResult>>? completer;

  ActivitySyncResult result(String localId) => ActivitySyncResult(
    localId: localId,
    fieldOperationId: 'operation-$localId',
    entryId: 'entry-$localId',
    inputsCount: 0,
    syncedAt: DateTime.utc(2026, 10, 30, 16),
  );

  @override
  Future<List<Map<String, dynamic>>> fetchInputPage({
    required int from,
    required int to,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchMixturePage({
    required int from,
    required int to,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchMachinePage({
    required int from,
    required int to,
  }) async => const [];

  @override
  Future<List<ActivitySyncResult>> syncEntries(
    Map<String, dynamic> payload,
  ) async {
    syncCalls++;
    if (throwSync) throw StateError('offline');
    final pending = completer;
    if (pending != null) return pending.future;
    final entries = payload['entries']! as List;
    return [
      for (final entry in entries.cast<Map<String, dynamic>>())
        result(entry['localId']! as String),
    ];
  }
}

class _FarmRemote implements FarmRemoteDataSource {
  @override
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchPlantRowsPage({
    required int from,
    required int to,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({
    int pageSize = 1000,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchZonesRows() async => const [];
}

class _InspectionRemote implements InspectionRemoteDataSource {
  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async => const [];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async => const {};

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async =>
      const [];

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async =>
      InspectionSnapshot(
        plants: const [],
        types: const [],
        loadedAt: DateTime.now(),
      );

  @override
  Future<List<AddedPlantSyncResult>> syncAddedPlants(
    Map<String, dynamic> payload,
  ) async => const [];

  @override
  Future<InspectionSyncResult> syncInspection(
    Map<String, dynamic> payload,
  ) async => const InspectionSyncResult(
    operationId: 'operation',
    created: 0,
    updated: 0,
    resolved: 0,
  );
}
