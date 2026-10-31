import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/activity_models.dart';
import 'activity_database.dart';

class ActivityLocalStore {
  ActivityLocalStore(this.database, {String Function()? newId})
    : newId = newId ?? const Uuid().v4;

  final ActivityDatabase database;
  final String Function() newId;

  String createLocalId() => newId();

  Future<ActivityEntry> create({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
    List<ActivityInput> inputs = const [],
    String? localId,
  }) async {
    final effectiveInputs = mixture == null
        ? inputs
        : mixture.inputs
              .map(
                (item) => ActivityInput(
                  localId: createLocalId(),
                  inputId: item.inputId,
                  nameSnapshot: item.name,
                  activeIngredientSnapshot: item.activeIngredient,
                  labelDoseSnapshot: item.labelDose,
                  doseUnitSnapshot: item.doseUnit,
                  appliedDose: item.dose,
                ),
              )
              .toList(growable: false);
    final entry = ActivityEntry(
      localId: localId ?? createLocalId(),
      geometry: geometry,
      activity: activity,
      performedAt: performedAt,
      responsible: responsible,
      mixtureId: mixture?.id,
      mixtureNameSnapshot: mixture?.name,
      machineId: machine?.id,
      machineNameSnapshot: machine?.name,
      machineBrandSnapshot: machine?.brand,
      inputs: effectiveInputs,
    );
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.insert('local_activity_entries', {
        'local_id': entry.localId,
        'geometry_type': entry.geometry.type.value,
        'geometry_geojson': jsonEncode(entry.geometry.toGeoJson()),
        'activity': entry.activity,
        'performed_at': entry.performedAt.toUtc().toIso8601String(),
        'responsible': entry.responsible,
        'mixture_id': entry.mixtureId,
        'mixture_name_snapshot': entry.mixtureNameSnapshot,
        'machine_id': entry.machineId,
        'machine_name_snapshot': entry.machineNameSnapshot,
        'machine_brand_snapshot': entry.machineBrandSnapshot,
        'payload_fingerprint': entry.canonicalPayload,
        'sync_status': entry.syncStatus.name,
      });
      await _insertInputs(txn, entry);
    });
    return entry;
  }

  Future<void> _insertInputs(DatabaseExecutor txn, ActivityEntry entry) async {
    for (final item in entry.inputs) {
      await txn.insert('local_activity_entry_inputs', {
        'local_id': item.localId,
        'entry_local_id': entry.localId,
        'input_id': item.inputId,
        'name_snapshot': item.nameSnapshot,
        'active_ingredient_snapshot': item.activeIngredientSnapshot,
        'label_dose_snapshot': item.labelDoseSnapshot,
        'dose_unit_snapshot': item.doseUnitSnapshot,
        'applied_dose': item.appliedDose.trim(),
      });
    }
  }

  Future<List<ActivityEntry>> list() async {
    final db = await database.database;
    final rows = await db.query(
      'local_activity_entries',
      orderBy: 'performed_at DESC, local_id DESC',
    );
    final entries = <ActivityEntry>[];
    for (final row in rows) {
      entries.add(await _fromRow(db, row));
    }
    return entries;
  }

  Future<ActivityEntry?> find(String localId) async {
    final db = await database.database;
    final rows = await db.query(
      'local_activity_entries',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(db, rows.single);
  }

  Future<bool> delete(String localId) async {
    final db = await database.database;
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        'local_activity_entries',
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      return deleted > 0;
    });
  }

  Future<List<ActivityEntry>> listSyncable() async {
    final db = await database.database;
    final rows = await db.query(
      'local_activity_entries',
      where: "sync_status IN ('pending','error')",
      orderBy: 'performed_at, local_id',
    );
    final entries = <ActivityEntry>[];
    for (final row in rows) {
      entries.add(await _fromRow(db, row));
    }
    return entries;
  }

  Future<ActivityEntry> _fromRow(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final inputRows = await db.query(
      'local_activity_entry_inputs',
      where: 'entry_local_id = ?',
      whereArgs: [row['local_id']],
      orderBy: 'name_snapshot, input_id',
    );
    final geometryJson = Map<String, dynamic>.from(
      jsonDecode(row['geometry_geojson']! as String) as Map,
    );
    return ActivityEntry(
      localId: row['local_id']! as String,
      geometry: ActivityGeometry.fromGeoJson(geometryJson),
      activity: row['activity']! as String,
      performedAt: DateTime.parse(row['performed_at']! as String),
      responsible: row['responsible']! as String,
      mixtureId: row['mixture_id'] as String?,
      mixtureNameSnapshot: row['mixture_name_snapshot'] as String?,
      machineId: row['machine_id'] as String?,
      machineNameSnapshot: row['machine_name_snapshot'] as String?,
      machineBrandSnapshot: row['machine_brand_snapshot'] as String?,
      inputs: inputRows
          .map(
            (input) => ActivityInput(
              localId: input['local_id']! as String,
              inputId: input['input_id']! as String,
              nameSnapshot: input['name_snapshot']! as String,
              activeIngredientSnapshot:
                  input['active_ingredient_snapshot'] as String?,
              labelDoseSnapshot: input['label_dose_snapshot'] as String?,
              doseUnitSnapshot: input['dose_unit_snapshot'] as String?,
              appliedDose: input['applied_dose']! as String,
            ),
          )
          .toList(),
      syncStatus: ActivitySyncStatus.values.byName(
        row['sync_status']! as String,
      ),
      error: row['error'] as String?,
      remoteFieldOperationId: row['remote_field_operation_id'] as String?,
      remoteEntryId: row['remote_entry_id'] as String?,
      syncedAt: row['synced_at'] == null
          ? null
          : DateTime.parse(row['synced_at']! as String),
    );
  }

  Future<void> markSyncing(Iterable<String> localIds) => _updateMany(localIds, {
    'sync_status': ActivitySyncStatus.syncing.name,
    'error': null,
  });

  Future<void> markError(Iterable<String> localIds, Object error) =>
      _updateMany(localIds, {
        'sync_status': ActivitySyncStatus.error.name,
        'error': error.toString(),
      });

  Future<void> markSynced(ActivitySyncResult result) => _updateMany(
    [result.localId],
    {
      'sync_status': ActivitySyncStatus.synced.name,
      'error': null,
      'remote_field_operation_id': result.fieldOperationId,
      'remote_entry_id': result.entryId,
      'synced_at': result.syncedAt.toUtc().toIso8601String(),
    },
  );

  Future<void> _updateMany(
    Iterable<String> localIds,
    Map<String, Object?> values,
  ) async {
    final ids = localIds.toList(growable: false);
    if (ids.isEmpty) return;
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'local_activity_entries',
          values,
          where: 'local_id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
