import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/spraying_models.dart';
import 'spraying_database.dart';

class SprayingLocalStore {
  const SprayingLocalStore(this._db);

  final SprayingDatabase _db;

  Future<String> getDeviceId() => _db.deviceId;

  Future<Database> get _database => _db.database;

  /// Salva ou atualiza a operação principal de pulverização no SQLite.
  Future<void> saveOperation(SprayingOperation op) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'local_spraying_operations',
        {
          'local_id': op.localId,
          'zone_id': op.zoneId,
          'operator_name': op.operatorName,
          'started_at': op.startedAt.toUtc().toIso8601String(),
          'finished_at': op.finishedAt.toUtc().toIso8601String(),
          'title': op.title,
          'machine_name': op.machineName,
          'tractor_identifier': op.tractorIdentifier,
          'notes': op.notes,
          'sync_status': op.syncStatus.toDbValue(),
          'remote_field_operation_id': op.remoteFieldOperationId,
          'synced_at': op.syncedAt?.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (op.route != null) {
        await _saveRouteTxn(txn, op.localId, op.route!);
      }

      if (op.trackPoints.isNotEmpty) {
        await _saveTrackPointsTxn(txn, op.localId, op.trackPoints);
      }

      if (op.inputs.isNotEmpty) {
        await _saveInputsTxn(txn, op.localId, op.inputs);
      }

      if (op.confirmedPlants.isNotEmpty) {
        await _saveConfirmedPlantsTxn(txn, op.localId, op.confirmedPlants);
      }
    });
    _db.publishCommit();
  }

  Future<void> _saveTrackPointsTxn(
    DatabaseExecutor txn,
    String operationLocalId,
    List<SprayingTrackPoint> points,
  ) async {
    for (final point in points) {
      await txn.insert(
        'local_spraying_track_points',
        {
          'local_id': point.localId,
          'operation_local_id': operationLocalId,
          'recorded_at': point.recordedAt.toUtc().toIso8601String(),
          'latitude': point.latitude,
          'longitude': point.longitude,
          'speed_mps': point.speedMps,
          'accuracy_m': point.accuracyM,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Insere um único ponto GPS coletado na sessão de rastreamento.
  Future<void> insertTrackPoint(
    String operationLocalId,
    SprayingTrackPoint point,
  ) async {
    final db = await _database;
    await db.insert('local_spraying_track_points', {
      'local_id': point.localId,
      'operation_local_id': operationLocalId,
      'recorded_at': point.recordedAt.toUtc().toIso8601String(),
      'latitude': point.latitude,
      'longitude': point.longitude,
      'speed_mps': point.speedMps,
      'accuracy_m': point.accuracyM,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insere um lote de pontos GPS coletados.
  Future<void> insertTrackPointsBatch(
    String operationLocalId,
    List<SprayingTrackPoint> points,
  ) async {
    if (points.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert('local_spraying_track_points', {
        'local_id': point.localId,
        'operation_local_id': operationLocalId,
        'recorded_at': point.recordedAt.toUtc().toIso8601String(),
        'latitude': point.latitude,
        'longitude': point.longitude,
        'speed_mps': point.speedMps,
        'accuracy_m': point.accuracyM,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Salva a rota da operação.
  Future<void> saveRoute(String operationLocalId, SprayingRoute route) async {
    final db = await _database;
    await _saveRouteTxn(db, operationLocalId, route);
    _db.publishCommit();
  }

  Future<void> _saveRouteTxn(
    DatabaseExecutor txn,
    String operationLocalId,
    SprayingRoute route,
  ) async {
    await txn.insert(
      'local_spraying_routes',
      {
        'local_id': route.localId,
        'operation_local_id': operationLocalId,
        'geojson': jsonEncode(route.geojson),
        'distance_meters': route.distanceMeters,
        'started_at': route.startedAt.toUtc().toIso8601String(),
        'finished_at': route.finishedAt.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Salva a lista de insumos de uma operação.
  Future<void> saveInputs(
    String operationLocalId,
    List<SprayingInput> inputs,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _saveInputsTxn(txn, operationLocalId, inputs);
    });
    _db.publishCommit();
  }

  Future<void> _saveInputsTxn(
    DatabaseExecutor txn,
    String operationLocalId,
    List<SprayingInput> inputs,
  ) async {
    await txn.delete(
      'local_spraying_inputs',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
    );
    for (final input in inputs) {
      await txn.insert(
        'local_spraying_inputs',
        {
          'local_id': input.localId,
          'operation_local_id': operationLocalId,
          'input_type': input.inputType,
          'product_name': input.productName,
          'active_ingredient': input.activeIngredient,
          'dose': input.dose,
          'dose_unit': input.doseUnit,
          'total_quantity': input.totalQuantity,
          'total_quantity_unit': input.totalQuantityUnit,
          'notes': input.notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Salva a lista de plantas confirmadas/revisadas.
  Future<void> saveConfirmedPlants(
    String operationLocalId,
    List<SprayingConfirmedPlant> plants,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _saveConfirmedPlantsTxn(txn, operationLocalId, plants);
    });
    _db.publishCommit();
  }

  Future<void> _saveConfirmedPlantsTxn(
    DatabaseExecutor txn,
    String operationLocalId,
    List<SprayingConfirmedPlant> plants,
  ) async {
    await txn.delete(
      'local_spraying_confirmed_plants',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
    );
    for (final plant in plants) {
      await txn.insert(
        'local_spraying_confirmed_plants',
        {
          'local_id': plant.localId,
          'operation_local_id': operationLocalId,
          'plant_id': plant.plantId,
          'match_source': plant.matchSource.value,
          'matched_at': plant.matchedAt?.toUtc().toIso8601String(),
          'nearest_track_point_local_id': plant.nearestTrackPointLocalId,
          'distance_meters': plant.distanceMeters,
          'notes': plant.notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Atualiza o status de sincronização de uma operação.
  Future<void> updateSyncStatus(
    String operationLocalId,
    SprayingSyncStatus status, {
    String? remoteId,
    DateTime? syncedAt,
  }) async {
    final db = await _database;
    final values = <String, dynamic>{'sync_status': status.toDbValue()};
    if (remoteId != null) {
      values['remote_field_operation_id'] = remoteId;
    }
    if (syncedAt != null) {
      values['synced_at'] = syncedAt.toUtc().toIso8601String();
    }
    await db.update(
      'local_spraying_operations',
      values,
      where: 'local_id = ?',
      whereArgs: [operationLocalId],
    );
    _db.publishCommit();
  }

  /// Obtém uma operação completa pelo seu ID local.
  Future<SprayingOperation?> getOperation(String operationLocalId) async {
    final db = await _database;
    final opRows = await db.query(
      'local_spraying_operations',
      where: 'local_id = ?',
      whereArgs: [operationLocalId],
    );
    if (opRows.isEmpty) return null;

    final opRow = opRows.single;
    final routeRows = await db.query(
      'local_spraying_routes',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
    );
    final trackPointRows = await db.query(
      'local_spraying_track_points',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
      orderBy: 'recorded_at ASC',
    );
    final inputRows = await db.query(
      'local_spraying_inputs',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
    );
    final plantRows = await db.query(
      'local_spraying_confirmed_plants',
      where: 'operation_local_id = ?',
      whereArgs: [operationLocalId],
    );

    return SprayingOperation(
      localId: opRow['local_id'] as String,
      zoneId: opRow['zone_id'] as String,
      startedAt: DateTime.parse(opRow['started_at'] as String),
      finishedAt: DateTime.parse(opRow['finished_at'] as String),
      operatorName: opRow['operator_name'] as String,
      title: opRow['title'] as String?,
      machineName: opRow['machine_name'] as String?,
      tractorIdentifier: opRow['tractor_identifier'] as String?,
      notes: opRow['notes'] as String?,
      syncStatus: SprayingSyncStatus.fromString(opRow['sync_status'] as String?),
      remoteFieldOperationId: opRow['remote_field_operation_id'] as String?,
      syncedAt: opRow['synced_at'] != null
          ? DateTime.parse(opRow['synced_at'] as String)
          : null,
      route: routeRows.isNotEmpty
          ? SprayingRoute.fromJson(routeRows.single)
          : null,
      trackPoints: trackPointRows.map(SprayingTrackPoint.fromJson).toList(),
      inputs: inputRows.map(SprayingInput.fromJson).toList(),
      confirmedPlants: plantRows.map(SprayingConfirmedPlant.fromJson).toList(),
    );
  }

  /// Lista todas as operações salvas no SQLite, ordenadas da mais recente para a mais antiga.
  Future<List<SprayingOperation>> listOperations() async {
    final db = await _database;
    final opRows = await db.query(
      'local_spraying_operations',
      orderBy: 'started_at DESC',
    );

    final result = <SprayingOperation>[];
    for (final opRow in opRows) {
      final opId = opRow['local_id'] as String;
      final routeRows = await db.query(
        'local_spraying_routes',
        where: 'operation_local_id = ?',
        whereArgs: [opId],
      );
      final trackPointRows = await db.query(
        'local_spraying_track_points',
        where: 'operation_local_id = ?',
        whereArgs: [opId],
        orderBy: 'recorded_at ASC',
      );
      final inputRows = await db.query(
        'local_spraying_inputs',
        where: 'operation_local_id = ?',
        whereArgs: [opId],
      );
      final plantRows = await db.query(
        'local_spraying_confirmed_plants',
        where: 'operation_local_id = ?',
        whereArgs: [opId],
      );

      result.add(
        SprayingOperation(
          localId: opId,
          zoneId: opRow['zone_id'] as String,
          startedAt: DateTime.parse(opRow['started_at'] as String),
          finishedAt: DateTime.parse(opRow['finished_at'] as String),
          operatorName: opRow['operator_name'] as String,
          title: opRow['title'] as String?,
          machineName: opRow['machine_name'] as String?,
          tractorIdentifier: opRow['tractor_identifier'] as String?,
          notes: opRow['notes'] as String?,
          syncStatus: SprayingSyncStatus.fromString(
            opRow['sync_status'] as String?,
          ),
          remoteFieldOperationId: opRow['remote_field_operation_id'] as String?,
          syncedAt: opRow['synced_at'] != null
              ? DateTime.parse(opRow['synced_at'] as String)
              : null,
          route: routeRows.isNotEmpty
              ? SprayingRoute.fromJson(routeRows.single)
              : null,
          trackPoints: trackPointRows.map(SprayingTrackPoint.fromJson).toList(),
          inputs: inputRows.map(SprayingInput.fromJson).toList(),
          confirmedPlants: plantRows
              .map(SprayingConfirmedPlant.fromJson)
              .toList(),
        ),
      );
    }
    return result;
  }

  /// Remove uma operação e seus filhos (em cascata).
  Future<void> deleteOperation(String operationLocalId) async {
    final db = await _database;
    await db.delete(
      'local_spraying_operations',
      where: 'local_id = ?',
      whereArgs: [operationLocalId],
    );
    _db.publishCommit();
  }
}
