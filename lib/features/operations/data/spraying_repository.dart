import 'dart:async';

import 'package:uuid/uuid.dart';

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
  Future<void> saveConfirmedPlants(
    String operationLocalId,
    List<SprayingConfirmedPlant> plants,
  );
  Future<List<SprayingOperation>> listOperations();
  Future<SprayingOperation?> getOperation(String operationLocalId);
  Future<void> deleteOperation(String operationLocalId);
  Future<SprayingSyncResult> syncOperation(String operationLocalId);
  Future<int> syncAllReviewed();
  Future<List<SprayingConfirmedPlant>> calculateAffectedPlants({
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
  Future<void> saveConfirmedPlants(
    String operationLocalId,
    List<SprayingConfirmedPlant> plants,
  ) => localStore.saveConfirmedPlants(operationLocalId, plants);

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

    if (op.route == null) {
      throw StateError('A operação não possui rota gravada');
    }

    var effectiveOp = op;

    // Se houver menos de 2 trackPoints mas a rota tiver coordenadas no GeoJSON,
    // reconstrói os trackPoints a partir da geometria da rota para viabilizar o sync.
    if (effectiveOp.trackPoints.length < 2 && effectiveOp.route != null) {
      final geojson = effectiveOp.route!.geojson;
      final coords = geojson['geometry']?['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        final duration = effectiveOp.finishedAt.difference(effectiveOp.startedAt);
        final stepMs = coords.length > 1
            ? (duration.inMilliseconds / (coords.length - 1)).round()
            : 0;
        final reconstructed = <SprayingTrackPoint>[];
        for (var i = 0; i < coords.length; i++) {
          final c = coords[i] as List;
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          reconstructed.add(
            SprayingTrackPoint(
              localId: const Uuid().v4(),
              recordedAt: effectiveOp.startedAt.add(Duration(milliseconds: stepMs * i)),
              latitude: lat,
              longitude: lon,
            ),
          );
        }
        await localStore.insertTrackPointsBatch(operationLocalId, reconstructed);
        effectiveOp = effectiveOp.copyWith(trackPoints: reconstructed);
      }
    }

    if (effectiveOp.trackPoints.length < 2) {
      throw StateError('A rota precisa de pelo menos 2 pontos GPS');
    }

    if (effectiveOp.inputs.isEmpty) {
      throw StateError('Ao menos um insumo é obrigatório para sincronizar');
    }

    await localStore.updateSyncStatus(
      operationLocalId,
      SprayingSyncStatus.syncing,
    );

    try {
      final deviceId = await localStore.getDeviceId();
      final payload = effectiveOp.toRpcPayload(deviceId: deviceId);
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
    final reviewed = operations.where(
      (op) =>
          op.syncStatus == SprayingSyncStatus.reviewed ||
          op.syncStatus == SprayingSyncStatus.error,
    );

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
  Future<List<SprayingConfirmedPlant>> calculateAffectedPlants({
    required SprayingOperation operation,
    required List<InspectionPlant> candidatePlants,
    double maxDistanceMeters = 9.0,
  }) async {
    // 1. Tenta calcular via RPC remota (recalculate_operation_affected_plants)
    if (operation.route?.geojson != null) {
      try {
        final remoteMatches = await remoteDataSource.recalculateAffectedPlants(
          geojson: operation.route!.geojson,
          zoneId: operation.zoneId.isNotEmpty ? operation.zoneId : null,
          maxDistanceMeters: maxDistanceMeters,
        );

        if (remoteMatches.isNotEmpty) {
          final now = DateTime.now().toUtc();
          return remoteMatches.map((m) {
            final plantId = (m['plant_id'] ?? m['plantId']) as String;
            final dist = (m['distance_meters'] ?? m['distanceMeters'] as num?)
                ?.toDouble();
            return SprayingConfirmedPlant(
              localId: const Uuid().v4(),
              plantId: plantId,
              matchSource: SprayingMatchSource.autoMatched,
              matchedAt: now,
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
