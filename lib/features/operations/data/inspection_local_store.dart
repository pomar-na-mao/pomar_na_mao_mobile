import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../farm/domain/user_location.dart';
import '../domain/inspection_models.dart';
import 'inspection_database.dart';

class InspectionLocalStore {
  InspectionLocalStore(this.database, {DateTime Function()? clock, String Function()? newId})
    : clock = clock ?? DateTime.now, newId = newId ?? const Uuid().v4;
  final InspectionDatabase database;
  final DateTime Function() clock;
  final String Function() newId;

  Future<InspectionSnapshot?> readSnapshot() async {
    final db = await database.database;
    return db.transaction((txn) async {
      final metadata = (await txn.query('installation')).single;
      if (metadata['loaded_at'] == null) return null;
      return InspectionSnapshot(
        plants: (await txn.query('cached_plants', orderBy: 'id'))
          .map((r) => InspectionPlant.fromJson(decodeInspectionJson(r['snapshot']))).toList(),
        types: (await txn.query('occurrence_types', orderBy: 'name, id'))
          .map((r) => OccurrenceType.fromJson(r)).toList(),
        loadedAt: DateTime.parse(metadata['loaded_at'] as String));
    });
  }

  Future<void> saveCatalog(List<OccurrenceType> types) async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final type in types) {
        await txn.insert('occurrence_types', type.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<OccurrenceType>> readCatalog() async =>
    (await (await database.database).query('occurrence_types', orderBy: 'name, id'))
      .map((r) => OccurrenceType.fromJson(r)).toList();

  Future<void> replaceSnapshot(InspectionSnapshot snapshot) async {
    if (snapshot.types.isEmpty) throw StateError('Catálogo indisponível. Verifique o acesso e carregue novamente.');
    final db = await database.database;
    await db.transaction((txn) async {
      final effective = {for (final plant in snapshot.plants) plant.id: plant};
      final previous = {for (final row in await txn.query('cached_plants'))
        row['id'] as String: InspectionPlant.fromJson(decodeInspectionJson(row['snapshot']))};
      final pending = await txn.rawQuery('''SELECT c.* FROM local_inspection_changes c
        JOIN local_inspections i ON i.local_id = c.inspection_local_id
        WHERE i.sync_status != 'synced' ORDER BY i.rowid, c.sequence''');
      for (final change in pending) {
        final id = change['plant_id'] as String;
        var plant = effective[id] ?? previous[id]?.withState({}, eligible: false);
        if (plant == null) throw StateError('Snapshot local incompleto');
        final types = {...plant.openTypeIds};
        if (change['change_type'] == 'add_occurrence') {
          types.add(change['occurrence_type_id'] as String);
        } else { types.remove(change['occurrence_type_id']); }
        effective[id] = plant.withState(types);
      }
      await txn.delete('cached_plants');
      final batch = txn.batch();
      for (final plant in effective.values) {
        batch.insert('cached_plants', {'id': plant.id, 'snapshot': jsonEncode(plant.toJson())});
      }
      // Keep retired types referenced by pending changes available for audit/editing.
      for (final type in snapshot.types) {
        batch.insert('occurrence_types', type.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await txn.update('installation', {'loaded_at': snapshot.loadedAt.toIso8601String()});
      final draft = await _ensureDraft(txn);
      await _capturePlants(txn, draft);
    });
  }

  Future<String> _ensureDraft(Transaction txn) async {
    final rows = await txn.query('local_inspections', where: "state = 'in_progress'");
    if (rows.isNotEmpty) return rows.single['local_id'] as String;
    final id = newId();
    await txn.insert('local_inspections', {'local_id': id,
      'started_at': clock().toUtc().toIso8601String(), 'state': 'in_progress', 'sync_status': 'pending'});
    await _capturePlants(txn, id);
    return id;
  }

  Future<void> _capturePlants(Transaction txn, String id) => txn.execute('''
    INSERT OR IGNORE INTO local_inspection_loaded_plants(inspection_local_id,plant_id,snapshot)
    SELECT ?, id, snapshot FROM cached_plants''', [id]);

  Future<void> toggle(String plantId, String typeId, {UserLocation? location, double? distance}) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final metadata = (await txn.query('installation')).single;
      final rows = await txn.query('cached_plants', where: 'id = ?', whereArgs: [plantId]);
      final type = await txn.query('occurrence_types', where: 'id = ?', whereArgs: [typeId]);
      if (metadata['loaded_at'] == null || rows.isEmpty || type.isEmpty) {
        throw StateError('Carregue o estado completo da planta antes de editar.');
      }
      final plant = InspectionPlant.fromJson(decodeInspectionJson(rows.single['snapshot']));
      final draftId = await _ensureDraft(txn);
      final draft = (await txn.query('local_inspections', where: 'local_id = ?', whereArgs: [draftId])).single;
      final sequence = (draft['last_sequence'] as int) + 1;
      var time = clock().toUtc();
      final last = draft['last_changed_at'] as String?;
      if (last != null && !time.isAfter(DateTime.parse(last))) {
        time = DateTime.parse(last).add(const Duration(microseconds: 1));
      }
      final added = !plant.openTypeIds.contains(typeId);
      await txn.insert('local_inspection_changes', {'local_id': newId(),
        'inspection_local_id': draftId, 'plant_id': plantId, 'occurrence_type_id': typeId,
        'change_type': added ? 'add_occurrence' : 'remove_occurrence',
        'sequence': sequence, 'changed_at': time.toIso8601String(),
        'latitude': location?.latitude, 'longitude': location?.longitude,
        'accuracy': location?.accuracy, 'distance': distance});
      final selected = {...plant.openTypeIds};
      if (added) { selected.add(typeId); } else { selected.remove(typeId); }
      await txn.update('cached_plants', {'snapshot': jsonEncode(plant.withState(selected).toJson())},
        where: 'id = ?', whereArgs: [plantId]);
      await txn.rawUpdate('''UPDATE local_inspections SET last_sequence = ?, last_changed_at = ?,
        changes_count = changes_count + 1,
        plants_count = (SELECT COUNT(DISTINCT plant_id) FROM local_inspection_changes WHERE inspection_local_id = ?)
        WHERE local_id = ?''', [sequence, time.toIso8601String(), draftId, draftId]);
    });
  }

  Future<LocalInspection?> finalize() async {
    final db = await database.database;
    return db.transaction((txn) async {
      final drafts = await txn.query('local_inspections', where: "state = 'in_progress'");
      if (drafts.isEmpty || drafts.single['changes_count'] == 0) return null;
      final draft = drafts.single;
      final id = draft['local_id'] as String;
      final rows = await txn.query('local_inspection_changes',
        where: 'inspection_local_id = ?', whereArgs: [id], orderBy: 'sequence');
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final change = _change(row);
        (grouped[change.plantId] ??= []).add(change.toPayload());
      }
      var finished = clock().toUtc();
      final last = DateTime.parse(draft['last_changed_at'] as String);
      if (finished.isBefore(last)) finished = last;
      final previous = await txn.rawQuery('SELECT finished_at FROM local_inspections WHERE finished_at IS NOT NULL ORDER BY rowid DESC LIMIT 1');
      if (previous.isNotEmpty) {
        final previousTime = DateTime.parse(previous.single['finished_at'] as String);
        if (!finished.isAfter(previousTime)) finished = previousTime.add(const Duration(microseconds: 1));
      }
      final device = (await txn.query('installation')).single['device_id'];
      final payload = jsonEncode({'deviceId': device, 'localInspectionId': id,
        'startedAt': draft['started_at'], 'finishedAt': finished.toIso8601String(),
        'zoneId': null, 'occurrenceTypeId': null,
        'plantsChanged': [for (final entry in grouped.entries) {'plantId': entry.key, 'changes': entry.value}]});
      await txn.update('local_inspections', {'finished_at': finished.toIso8601String(),
        'state': 'finished', 'payload': payload}, where: 'local_id = ?', whereArgs: [id]);
      return _inspection((await txn.query('local_inspections', where: 'local_id = ?', whereArgs: [id])).single);
    });
  }

  Future<List<LocalInspection>> list() async =>
    (await (await database.database).query('local_inspections', orderBy: 'rowid DESC')).map(_inspection).toList();
  Future<List<LocalInspection>> pending() async =>
    (await (await database.database).query('local_inspections',
      where: "state = 'finished' AND sync_status != 'synced'", orderBy: 'rowid')).map(_inspection).toList();
  Future<List<InspectionChange>> changes(String id) async =>
    (await (await database.database).query('local_inspection_changes',
      where: 'inspection_local_id = ?', whereArgs: [id], orderBy: 'sequence')).map(_change).toList();
  Future<void> markSyncing(String id) async {
    await (await database.database).update('local_inspections', {'sync_status': 'syncing', 'error': null},
      where: 'local_id = ? AND state = ?', whereArgs: [id, 'finished']);
  }
  Future<void> markError(String id, Object error) async {
    final str = error.toString();
    final lower = str.toLowerCase();
    final isNetwork = lower.contains('sem internet') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('clientexception') ||
        lower.contains('offline') ||
        lower.contains('sem conexão') ||
        lower.contains('sem conexao') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('unreachable');
    final syncStatus = isNetwork ? 'pending' : 'error';
    final formatted = isNetwork ? 'Sem internet' : str;
    await (await database.database).update('local_inspections', {'sync_status': syncStatus, 'error': formatted},
      where: 'local_id = ?', whereArgs: [id]);
  }
  Future<void> acknowledge(String id, InspectionSyncResult result) async {
    await acknowledgeMerged(inspectionIds: [id], result: result);
  }

  Future<void> acknowledgeMerged({
    required List<String> inspectionIds,
    required InspectionSyncResult result,
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final now = clock().toUtc().toIso8601String();
      for (final id in inspectionIds) {
        await txn.update('local_inspections', {
          'state': 'synced',
          'sync_status': 'synced',
          'remote_id': result.operationId,
          'synced_at': now,
          'error': null,
        }, where: 'local_id = ?', whereArgs: [id]);

        await txn.update('local_inspection_changes', {
          'sync_status': 'synced',
        }, where: 'inspection_local_id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> removePlantFromInspection(String inspectionId, String plantId) async {
    final db = await database.database;
    await db.transaction((txn) async {
      // 1. Delete changes for this plant in this inspection
      await txn.delete(
        'local_inspection_changes',
        where: 'inspection_local_id = ? AND plant_id = ?',
        whereArgs: [inspectionId, plantId],
      );

      // 2. Recompute cached_plants for this plantId
      final loaded = await txn.query(
        'local_inspection_loaded_plants',
        where: 'plant_id = ?',
        whereArgs: [plantId],
        limit: 1,
      );
      if (loaded.isNotEmpty) {
        final plant = InspectionPlant.fromJson(decodeInspectionJson(loaded.single['snapshot']));
        final remainingPlantChanges = await txn.rawQuery('''
          SELECT c.* FROM local_inspection_changes c
          JOIN local_inspections i ON i.local_id = c.inspection_local_id
          WHERE c.plant_id = ? AND i.sync_status != 'synced'
          ORDER BY i.rowid, c.sequence
        ''', [plantId]);
        final types = {...plant.openTypeIds};
        for (final change in remainingPlantChanges) {
          if (change['change_type'] == 'add_occurrence') {
            types.add(change['occurrence_type_id'] as String);
          } else {
            types.remove(change['occurrence_type_id'] as String);
          }
        }
        await txn.update(
          'cached_plants',
          {'snapshot': jsonEncode(plant.withState(types).toJson())},
          where: 'id = ?',
          whereArgs: [plantId],
        );
      }

      // 3. Check remaining plants and changes for this inspection
      final remainingRows = await txn.query(
        'local_inspection_changes',
        where: 'inspection_local_id = ?',
        whereArgs: [inspectionId],
        orderBy: 'sequence',
      );

      final distinctPlants = remainingRows.map((r) => r['plant_id'] as String).toSet();
      final remainingChangesCount = remainingRows.length;
      final remainingPlantsCount = distinctPlants.length;

      if (remainingPlantsCount == 0) {
        // Remove all traces of the inspection if no plants remain
        await txn.delete(
          'local_inspection_changes',
          where: 'inspection_local_id = ?',
          whereArgs: [inspectionId],
        );
        await txn.delete(
          'local_inspection_loaded_plants',
          where: 'inspection_local_id = ?',
          whereArgs: [inspectionId],
        );
        await txn.delete(
          'local_inspections',
          where: 'local_id = ?',
          whereArgs: [inspectionId],
        );
      } else {
        // Update inspection counts and payload
        final inspectionRow = (await txn.query(
          'local_inspections',
          where: 'local_id = ?',
          whereArgs: [inspectionId],
        )).firstOrNull;

        if (inspectionRow != null) {
          String? newPayload = inspectionRow['payload'] as String?;
          if (newPayload != null) {
            try {
              final payloadMap = Map<String, dynamic>.from(jsonDecode(newPayload) as Map);
              final plantsChanged = (payloadMap['plantsChanged'] as List<dynamic>? ?? [])
                  .map((p) => Map<String, dynamic>.from(p as Map))
                  .where((p) => p['plantId'] != plantId)
                  .toList();
              payloadMap['plantsChanged'] = plantsChanged;
              newPayload = jsonEncode(payloadMap);
            } catch (_) {}
          }

          await txn.update(
            'local_inspections',
            {
              'plants_count': remainingPlantsCount,
              'changes_count': remainingChangesCount,
              'payload': ?newPayload,
            },
            where: 'local_id = ?',
            whereArgs: [inspectionId],
          );
        }
      }
    });
  }


  static LocalInspection _inspection(Map<String, Object?> r) => LocalInspection(
    id: r['local_id'] as String, startedAt: DateTime.parse(r['started_at'] as String),
    finishedAt: r['finished_at'] == null ? null : DateTime.parse(r['finished_at'] as String),
    status: InspectionSyncStatus.values.byName(r['sync_status'] as String),
    plantsCount: r['plants_count'] as int, changesCount: r['changes_count'] as int,
    error: r['error'] as String?, remoteId: r['remote_id'] as String?, payloadJson: r['payload'] as String?,
    syncedAt: r['synced_at'] == null ? null : DateTime.parse(r['synced_at'] as String));
  static InspectionChange _change(Map<String, Object?> r) => InspectionChange(
    id: r['local_id'] as String, plantId: r['plant_id'] as String, typeId: r['occurrence_type_id'] as String,
    added: r['change_type'] == 'add_occurrence', sequence: r['sequence'] as int,
    changedAt: DateTime.parse(r['changed_at'] as String), latitude: (r['latitude'] as num?)?.toDouble(),
    longitude: (r['longitude'] as num?)?.toDouble(), accuracy: (r['accuracy'] as num?)?.toDouble(),
    distance: (r['distance'] as num?)?.toDouble());
}
