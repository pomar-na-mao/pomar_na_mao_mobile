import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/harvest_forecast_models.dart';
import 'harvest_forecast_database.dart';

class HarvestForecastLocalStore {
  HarvestForecastLocalStore(
    this.database, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : clock = clock ?? DateTime.now,
       newId = newId ?? const Uuid().v4;

  final HarvestForecastDatabase database;
  final DateTime Function() clock;
  final String Function() newId;

  Future<String> get deviceId => database.deviceId;

  String createLocalId() => newId();

  Future<HarvestForecastMarking> create({
    String? localId,
    required double latitude,
    required double longitude,
    required HarvestForecastClassification classification,
    DateTime? createdAt,
  }) async {
    final marking = HarvestForecastMarking(
      localId: localId ?? newId(),
      latitude: latitude,
      longitude: longitude,
      classification: classification,
      createdAt: createdAt ?? clock(),
    );
    await (await database.database).insert(
      'local_harvest_forecast_markings',
      marking.toRow(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return marking;
  }

  Future<List<HarvestForecastMarking>> list() async =>
      (await (await database.database).query(
        'local_harvest_forecast_markings',
        orderBy: 'created_at DESC, local_id DESC',
      )).map(HarvestForecastMarking.fromRow).toList(growable: false);

  Future<HarvestForecastMarking?> find(String localId) async {
    final rows = await (await database.database).query(
      'local_harvest_forecast_markings',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : HarvestForecastMarking.fromRow(rows.single);
  }

  Future<List<HarvestForecastMarking>> listSyncable() async =>
      (await (await database.database).query(
        'local_harvest_forecast_markings',
        where: "sync_status IN ('pending','error')",
        orderBy: 'created_at ASC, local_id ASC',
      )).map(HarvestForecastMarking.fromRow).toList(growable: false);

  Future<HarvestForecastMarking?> updateClassification(
    String localId,
    HarvestForecastClassification classification,
  ) async {
    final db = await database.database;
    final updated = await db.update(
      'local_harvest_forecast_markings',
      {
        'classification': classification.code,
        'sync_status': HarvestForecastSyncStatus.pending.name,
        'error': null,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    if (updated == 0) return null;
    return find(localId);
  }

  Future<bool> delete(String localId) async {
    final db = await database.database;
    final deleted = await db.delete(
      'local_harvest_forecast_markings',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    return deleted > 0;
  }

  Future<void> markSyncing(Iterable<String> ids) =>
      _updateMany(ids, {'sync_status': 'syncing', 'error': null});

  Future<void> markError(Iterable<String> ids, String error) =>
      _updateMany(ids, {'sync_status': 'error', 'error': error});

  Future<void> markSynced(HarvestForecastSyncResult result) => _updateMany(
    [result.localMarkingId],
    {
      'sync_status': 'synced',
      'error': null,
      'remote_id': result.id,
      'remote_plant_id': result.plantId,
      'remote_zone_id': result.zoneId,
      'synced_at': result.syncedAt.toIso8601String(),
    },
  );

  Future<void> _updateMany(
    Iterable<String> ids,
    Map<String, Object?> values,
  ) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in uniqueIds) {
        await txn.update(
          'local_harvest_forecast_markings',
          values,
          where: 'local_id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
