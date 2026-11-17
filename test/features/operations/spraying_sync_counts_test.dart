import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
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
  bool recalculationCalled = false;

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
  }) async {
    recalculationCalled = true;
    return const [];
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);

  SprayingOperation operation({bool validRoute = true}) => SprayingOperation(
    localId: 'op-1',
    startedAt: now,
    finishedAt: now.add(const Duration(minutes: 1)),
    operatorName: 'Operador',
    syncStatus: SprayingSyncStatus.reviewed,
    route: SprayingRoute(
      localId: 'route-1',
      geojson: {
        'type': 'LineString',
        'coordinates': validRoute
            ? [
                [-47.0, -21.0],
                [-47.0, -21.0001],
              ]
            : <List<double>>[],
      },
      distanceMeters: 5,
      startedAt: now,
      finishedAt: now.add(const Duration(minutes: 1)),
    ),
    inputs: const [
      SprayingInput(
        localId: 'input-1',
        inputType: 'fungicide',
        productName: 'Produto 1',
      ),
    ],
  );

  final result = SprayingSyncResult(
    fieldOperationId: 'remote-op',
    routeId: 'remote-route',
    syncStatus: 'synced',
    syncedAt: now,
  );

  test('sync payload contains only operation and route data', () async {
    final store = _Store(operation());
    final remote = _Remote(result);
    final repository = DefaultSprayingRepository(
      localStore: store,
      remoteDataSource: remote,
    );

    await repository.syncOperation('op-1');

    expect(remote.payload, containsPair('operation', isA<Map>()));
    expect(remote.payload, containsPair('route', isA<Map>()));
    expect(remote.payload, isNot(contains('trackPoints')));
    expect(remote.payload, isNot(contains('inputs')));
    expect(remote.payload, isNot(contains('confirmedPlants')));
    expect(store.operation.syncStatus, SprayingSyncStatus.synced);
  });

  test('operation with invalid route is rejected before RPC', () async {
    final store = _Store(operation(validRoute: false));
    final remote = _Remote(result);
    final repository = DefaultSprayingRepository(
      localStore: store,
      remoteDataSource: remote,
    );

    await expectLater(repository.syncOperation('op-1'), throwsStateError);
    expect(remote.payload, isNull);
  });

  test('affected-plants RPC can return zero plants', () async {
    final remote = _Remote(result);
    final repository = DefaultSprayingRepository(
      localStore: _Store(operation()),
      remoteDataSource: remote,
    );

    final affected = await repository.calculateAffectedPlants(
      operation: operation(),
      candidatePlants: const <InspectionPlant>[],
    );

    expect(remote.recalculationCalled, isTrue);
    expect(affected, isEmpty);
  });
}
