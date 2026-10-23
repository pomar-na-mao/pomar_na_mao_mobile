import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/mipd_models.dart';
import 'mipd_database.dart';

class MipdLocalStore {
  MipdLocalStore(
    this.database, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : clock = clock ?? DateTime.now,
       newId = newId ?? const Uuid().v4;

  final MipdDatabase database;
  final DateTime Function() clock;
  final String Function() newId;

  Future<String> get deviceId => database.deviceId;

  Future<MipdMarking> create({
    String? localId,
    required String plantId,
    required String occurrenceTypeId,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
    DateTime? observedAt,
  }) async {
    final marking = MipdMarking(
      localId: localId ?? newId(),
      plantId: plantId,
      occurrenceTypeId: occurrenceTypeId,
      plantParts: plantParts,
      observedAt: observedAt ?? clock(),
      localPhotoPath: localPhotoPath,
    );
    await (await database.database).insert(
      'local_mipd_markings',
      marking.toRow(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return marking;
  }

  String createLocalId() => newId();

  Future<List<MipdMarking>> list() async =>
      (await (await database.database).query(
        'local_mipd_markings',
        orderBy: 'observed_at DESC, local_id DESC',
      )).map(MipdMarking.fromRow).toList(growable: false);

  Future<MipdMarking?> find(String localId) async {
    final rows = await (await database.database).query(
      'local_mipd_markings',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : MipdMarking.fromRow(rows.single);
  }

  Future<List<MipdMarking>> listSyncable() async =>
      (await (await database.database).query(
        'local_mipd_markings',
        where: "sync_status IN ('pending','error')",
        orderBy: 'observed_at, local_id',
      )).map(MipdMarking.fromRow).toList(growable: false);

  Future<void> markSyncing(Iterable<String> ids) =>
      _updateMany(ids, {'sync_status': 'syncing', 'error': null});

  Future<void> markError(Iterable<String> ids, String error) =>
      _updateMany(ids, {'sync_status': 'error', 'error': error});

  Future<void> setRemotePhotoPath(String id, String path) =>
      _updateMany([id], {'remote_photo_path': path});

  Future<void> markSynced(MipdSyncResult result) => _updateMany(
    [result.localMarkingId],
    {
      'sync_status': 'synced',
      'error': null,
      'remote_operation_id': result.operationId,
      'remote_occurrence_id': result.occurrenceId,
      'remote_marking_id': result.markingId,
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
          'local_mipd_markings',
          values,
          where: 'local_id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
