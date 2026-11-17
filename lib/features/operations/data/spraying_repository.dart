import 'dart:async';

import '../domain/inspection_models.dart';
import '../domain/spraying_geometry_service.dart';
import '../domain/spraying_models.dart';
import 'spraying_local_store.dart';
import 'spraying_remote_data_source.dart';

abstract interface class SprayingRepository {
  Future<void> saveOperation(SprayingOperation op);
  Future<void> saveRoute(String operationLocalId, SprayingRoute route);
  Future<void> addTrackPoint(String operationLocalId, SprayingTrackPoint point);
  Future<void> addTrackPoints(
    String operationLocalId,
    List<SprayingTrackPoint> points,
  );
  Future<void> saveInputs(String operationLocalId, List<SprayingInput> inputs);
  Future<List<SprayingOperation>> listOperations();
  Future<SprayingOperation?> getOperation(String operationLocalId);
  Future<void> deleteOperation(String operationLocalId);
  Future<SprayingSyncResult> syncOperation(String operationLocalId);
  Future<int> syncAllReviewed();
  Future<List<SprayingAffectedPlant>> calculateAffectedPlants({
    required SprayingOperation operation,
    required List<InspectionPlant> candidatePlants,
    double maxDistanceMeters = 9.0,
  });
}

class DefaultSprayingRepository implements SprayingRepository {
  DefaultSprayingRepository({
    required this.localStore,
    required this.remoteDataSource,
  });

  final SprayingLocalStore localStore;
  final SprayingRemoteDataSource remoteDataSource;

  @override
  Future<void> saveOperation(SprayingOperation op) =>
      localStore.saveOperation(op);

  @override
  Future<void> saveRoute(String operationLocalId, SprayingRoute route) =>
      localStore.saveRoute(operationLocalId, route);

  @override
  Future<void> addTrackPoint(
    String operationLocalId,
    SprayingTrackPoint point,
  ) => localStore.insertTrackPoint(operationLocalId, point);

  @override
  Future<void> addTrackPoints(
    String operationLocalId,
    List<SprayingTrackPoint> points,
  ) => localStore.insertTrackPointsBatch(operationLocalId, points);

  @override
  Future<void> saveInputs(
    String operationLocalId,
    List<SprayingInput> inputs,
  ) => localStore.saveInputs(operationLocalId, inputs);

  @override
  Future<List<SprayingOperation>> listOperations() =>
      localStore.listOperations();

  @override
  Future<SprayingOperation?> getOperation(String operationLocalId) =>
      localStore.getOperation(operationLocalId);

  @override
  Future<void> deleteOperation(String operationLocalId) =>
      localStore.deleteOperation(operationLocalId);

  @override
  Future<SprayingSyncResult> syncOperation(String operationLocalId) async {
    final op = await localStore.getOperation(operationLocalId);
    if (op == null) {
      throw StateError('Operação $operationLocalId não encontrada');
    }

    if (!op.hasValidRoute) {
      throw StateError('A operação precisa de uma rota válida');
    }

    await localStore.updateSyncStatus(
      operationLocalId,
      SprayingSyncStatus.syncing,
    );

    try {
      final deviceId = await localStore.getDeviceId();
      final payload = op.toRpcPayload(deviceId: deviceId);
      final result = await remoteDataSource.syncSprayingOperation(payload);

      await localStore.updateSyncStatus(
        operationLocalId,
        SprayingSyncStatus.synced,
        remoteId: result.fieldOperationId,
        syncedAt: result.syncedAt,
      );

      return result;
    } catch (e) {
      await localStore.updateSyncStatus(
        operationLocalId,
        SprayingSyncStatus.error,
      );
      rethrow;
    }
  }

  @override
  Future<int> syncAllReviewed() async {
    final operations = await localStore.listOperations();
    final reviewed = operations.where((op) => op.isEligibleForSync);

    var syncedCount = 0;
    for (final op in reviewed) {
      try {
        await syncOperation(op.localId);
        syncedCount++;
      } catch (_) {
        // Continua tentando sincronizar as demais operações
      }
    }
    return syncedCount;
  }

  @override
  Future<List<SprayingAffectedPlant>> calculateAffectedPlants({
    required SprayingOperation operation,
    required List<InspectionPlant> candidatePlants,
    double maxDistanceMeters = 9.0,
  }) async {
    // 1. Tenta calcular via RPC remota (recalculate_operation_affected_plants)
    if (operation.route?.geojson != null) {
      try {
        final remoteMatches = await remoteDataSource.recalculateAffectedPlants(
          geojson: operation.route!.geojson,
          zoneId: null,
          maxDistanceMeters: maxDistanceMeters,
        );

        if (remoteMatches.isNotEmpty) {
          return remoteMatches.map((m) {
            final plantId = (m['plant_id'] ?? m['plantId']) as String;
            final dist = (m['distance_meters'] ?? m['distanceMeters'] as num?)
                ?.toDouble();
            return SprayingAffectedPlant(
              plantId: plantId,
              distanceMeters: dist,
            );
          }).toList();
        }
      } catch (e) {
        // Fallback silencioso para cálculo geométrico offline
      }
    }

    // 2. Fallback offline: cálculo espacial com coordenadas locais e Haversine + Cross-track
    const geometry = SprayingGeometryService();
    return geometry.calculateAffectedPlants(
      candidatePlants: candidatePlants,
      trackPoints: operation.trackPoints,
      maxDistanceMeters: maxDistanceMeters,
    );
  }
}
