import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_models.dart';

class _Store extends SprayingLocalStore {
  _Store(this.operation)
    : super(SprayingDatabase(projectUrl: 'https://test.invalid'));

  SprayingOperation operation;

  @override
  Future<SprayingOperation?> getOperation(String operationLocalId) async =>
      operation;

  @override
  Future<String> getDeviceId() async => 'device-1';

  @override
  Future<void> updateSyncStatus(
    String operationLocalId,
    SprayingSyncStatus status, {
    String? remoteId,
    DateTime? syncedAt,
  }) async {
    operation = operation.copyWith(
      syncStatus: status,
      remoteFieldOperationId: remoteId,
      syncedAt: syncedAt,
    );
  }
}

class _Remote implements SprayingRemoteDataSource {
  _Remote(this.result);

  final SprayingSyncResult result;
  Map<String, dynamic>? payload;

  @override
  Future<SprayingSyncResult> syncSprayingOperation(
    Map<String, dynamic> payload,
  ) async {
    this.payload = payload;
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> recalculateAffectedPlants({
    required Map<String, dynamic> geojson,
    String? zoneId,
    double maxDistanceMeters = 9,
  }) async => const [];
}

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);

  SprayingOperation operation() => SprayingOperation(
    localId: 'op-1',
    zoneId: 'zone-b',
    startedAt: now,
    finishedAt: now.add(const Duration(minutes: 1)),
    operatorName: 'Operador',
    syncStatus: SprayingSyncStatus.reviewed,
    route: SprayingRoute(
      localId: 'route-1',
      geojson: const {'type': 'LineString', 'coordinates': []},
      distanceMeters: 5,
      startedAt: now,
      finishedAt: now.add(const Duration(minutes: 1)),
    ),
    trackPoints: [
      SprayingTrackPoint(
        localId: 'point-1',
        recordedAt: now,
        latitude: -21,
        longitude: -47,
      ),
      SprayingTrackPoint(
        localId: 'point-2',
        recordedAt: now.add(const Duration(seconds: 1)),
        latitude: -21.0001,
        longitude: -47,
      ),
    ],
    inputs: const [
      SprayingInput(
        localId: 'input-1',
        inputType: 'fungicide',
        productName: 'Produto 1',
      ),
      SprayingInput(
        localId: 'input-2',
        inputType: 'fungicide',
        productName: 'Produto 2',
      ),
    ],
    confirmedPlants: List.generate(
      16,
      (index) => SprayingConfirmedPlant(
        localId: 'match-$index',
        plantId: 'plant-$index',
        matchSource: SprayingMatchSource.autoMatched,
      ),
    ),
  );

  SprayingSyncResult result({required int plants, required int inputs}) =>
      SprayingSyncResult(
        fieldOperationId: 'remote-op',
        routeId: 'remote-route',
        trackPointsCount: 2,
        inputsCount: inputs,
        confirmedPlantsCount: plants,
        syncedAt: now,
      );

  for (final counts in [(0, 2), (16, 0)]) {
    test(
      'partial RPC count ${counts.$1}/${counts.$2} stays retryable',
      () async {
        final store = _Store(operation());
        final remote = _Remote(result(plants: counts.$1, inputs: counts.$2));
        final repository = DefaultSprayingRepository(
          localStore: store,
          remoteDataSource: remote,
        );

        await expectLater(
          repository.syncOperation('op-1'),
          throwsA(isA<StateError>()),
        );

        expect(store.operation.syncStatus, SprayingSyncStatus.error);
        expect((remote.payload!['confirmedPlants'] as List).length, 16);
        expect((remote.payload!['inputs'] as List).length, 2);
        expect((remote.payload!['operation'] as Map)['zoneId'], 'zone-b');
      },
    );
  }

  test('matching RPC counts mark the operation synced', () async {
    final store = _Store(operation());
    final repository = DefaultSprayingRepository(
      localStore: store,
      remoteDataSource: _Remote(result(plants: 16, inputs: 2)),
    );

    final synced = await repository.syncOperation('op-1');

    expect(synced.confirmedPlantsCount, 16);
    expect(synced.inputsCount, 2);
    expect(store.operation.syncStatus, SprayingSyncStatus.synced);
  });
}
