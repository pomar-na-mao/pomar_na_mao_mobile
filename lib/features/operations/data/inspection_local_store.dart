import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../farm/domain/user_location.dart';
import '../domain/inspection_models.dart';
import 'inspection_database.dart';
import '../../../core/diagnostics/runtime_diagnostics.dart';
import '../../../core/data/json_codec_worker.dart';

class InspectionLocalStore {
  InspectionLocalStore(
    this.database, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : clock = clock ?? DateTime.now,
       newId = newId ?? const Uuid().v4;
  final InspectionDatabase database;
  final DateTime Function() clock;
  final String Function() newId;

  static const plantsCacheKey = 'plants';
  static const farmCacheKey = 'farm';
  static const zonesCacheKey = 'zones';
  static const occurrenceTypesCacheKey = 'occurrence_types';

  Future<CachedPlantTotals?> readSharedPlantTotals() async {
    final db = await database.database;
    final rows = await db.query(
      'cache_metadata',
      columns: ['row_count', 'existing_plants', 'available_planting_spots'],
      where: 'cache_key = ? AND is_complete = 1',
      whereArgs: [plantsCacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['row_count'] == null ||
        row['existing_plants'] == null ||
        row['available_planting_spots'] == null) {
      final cachedPlants = await db.query('cached_plants');
      final totals = RuntimeDiagnostics.instance.measure(
        RuntimeStage.decode,
        () => CachedPlantTotals.fromPlants(
          cachedPlants.map(
            (cached) => InspectionPlant.fromJson(
              decodeInspectionJson(cached['snapshot']),
            ),
          ),
        ),
      );
      await db.update(
        'cache_metadata',
        {
          'row_count': totals.rowCount,
          'existing_plants': totals.existingPlants,
          'available_planting_spots': totals.availablePlantingSpots,
        },
        where: 'cache_key = ?',
        whereArgs: [plantsCacheKey],
      );
      return totals;
    }
    return CachedPlantTotals(
      rowCount: row['row_count'] as int,
      existingPlants: row['existing_plants'] as int,
      availablePlantingSpots: row['available_planting_spots'] as int,
    );
  }

  Future<bool> hasCompleteCache(String cacheKey) async {
    final rows = await (await database.database).query(
      'cache_metadata',
      columns: ['is_complete'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['is_complete'] == 1;
  }

  Future<List<Map<String, dynamic>>?> readSharedPlantRows() =>
      RuntimeDiagnostics.instance.track(
        RuntimeStage.localRead,
        _readSharedPlantRows,
      );

  Future<List<Map<String, dynamic>>?> _readSharedPlantRows() async {
    final db = await database.database;
    if (!await hasCompleteCache(plantsCacheKey)) return null;
    final rows = await db.query('cached_plants', orderBy: 'id');
    return RuntimeDiagnostics.instance.track(
      RuntimeStage.decode,
      () => decodeJsonMapsInWorker(rows.map((row) => row['snapshot'])),
    );
  }

  Future<void> replaceSharedPlantRows(
    List<Map<String, dynamic>> rows,
    Map<String, Set<String>> openOccurrences, {
    required DateTime loadedAt,
  }) => RuntimeDiagnostics.instance.track(
    RuntimeStage.persistence,
    () => _replaceSharedPlantRows(rows, openOccurrences, loadedAt: loadedAt),
  );

  Future<void> _replaceSharedPlantRows(
    List<Map<String, dynamic>> rows,
    Map<String, Set<String>> openOccurrences, {
    required DateTime loadedAt,
  }) async {
    final generationId = await beginPlantStaging(loadedAt: loadedAt);
    try {
      await appendStagedPlantRows(
        generationId,
        rows,
        openOccurrences: openOccurrences,
      );
      await publishPlantStaging(generationId);
    } catch (_) {
      await discardPlantStaging(generationId);
      rethrow;
    }
  }

  Future<String> beginPlantStaging({required DateTime loadedAt}) async {
    final generationId = newId();
    final db = await database.database;
    await db.insert('cache_generations', {
      'generation_id': generationId,
      'cache_key': plantsCacheKey,
      'started_at': clock().toUtc().toIso8601String(),
      'loaded_at': loadedAt.toUtc().toIso8601String(),
    });
    return generationId;
  }

  Future<void> appendStagedPlantRows(
    String generationId,
    List<Map<String, dynamic>> rows, {
    Map<String, Set<String>> openOccurrences = const {},
  }) async {
    final remotePlants = <String, InspectionPlant>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Planta remota sem identificador válido');
      }
      final nonExistent = row['non_existent'] as bool? ?? false;
      remotePlants[id] = InspectionPlant(
        id: id,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        description: row['description'] as String?,
        zoneId: row['zone_id'] as String?,
        openTypeIds: openOccurrences[id] ?? const <String>{},
        eligible: true,
        nonExistent: nonExistent,
      );
    }

    final plantEntries = remotePlants.values.toList(growable: false);
    final encodedSnapshots = await RuntimeDiagnostics.instance.track(
      RuntimeStage.decode,
      () => encodeJsonMapsInWorker(plantEntries.map((plant) => plant.toJson())),
    );

    final db = await database.database;
    await db.transaction((txn) async {
      final generation = await txn.query(
        'cache_generations',
        where: 'generation_id = ? AND cache_key = ? AND is_complete = 0',
        whereArgs: [generationId, plantsCacheKey],
        limit: 1,
      );
      if (generation.isEmpty) {
        throw StateError('Geracao de plantas indisponivel para staging');
      }
      final totals = CachedPlantTotals.fromPlants(plantEntries);
      final batch = txn.batch();
      for (var index = 0; index < plantEntries.length; index++) {
        final plant = plantEntries[index];
        batch.insert('staged_plants', {
          'generation_id': generationId,
          'id': plant.id,
          'snapshot': encodedSnapshots[index],
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }
      await batch.commit(noResult: true);
      await txn.rawUpdate(
        '''UPDATE cache_generations SET
          row_count = row_count + ?,
          existing_plants = existing_plants + ?,
          available_planting_spots = available_planting_spots + ?
        WHERE generation_id = ?''',
        [
          totals.rowCount,
          totals.existingPlants,
          totals.availablePlantingSpots,
          generationId,
        ],
      );
    });
  }

  Future<void> applyOpenOccurrencesToStaging(
    String generationId,
    Map<String, Set<String>> openOccurrences,
  ) async {
    if (openOccurrences.isEmpty) return;
    final db = await database.database;
    await db.transaction((txn) async {
      final generation = await txn.query(
        'cache_generations',
        where: 'generation_id = ? AND cache_key = ? AND is_complete = 0',
        whereArgs: [generationId, plantsCacheKey],
        limit: 1,
      );
      if (generation.isEmpty) {
        throw StateError('Geracao de plantas indisponivel para ocorrencias');
      }
      final batch = txn.batch();
      for (final entry in openOccurrences.entries) {
        final rows = await txn.query(
          'staged_plants',
          where: 'generation_id = ? AND id = ?',
          whereArgs: [generationId, entry.key],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final plant = InspectionPlant.fromJson(
          decodeInspectionJson(rows.single['snapshot']),
        );
        batch.update(
          'staged_plants',
          {'snapshot': jsonEncode(plant.withState(entry.value).toJson())},
          where: 'generation_id = ? AND id = ?',
          whereArgs: [generationId, entry.key],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> publishPlantStaging(String generationId) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final generation = await txn.query(
        'cache_generations',
        where: 'generation_id = ? AND cache_key = ? AND is_complete = 0',
        whereArgs: [generationId, plantsCacheKey],
        limit: 1,
      );
      if (generation.isEmpty) {
        throw StateError('Geracao de plantas indisponivel para publicacao');
      }
      final stagedRows = await txn.query(
        'staged_plants',
        where: 'generation_id = ?',
        whereArgs: [generationId],
        orderBy: 'id',
      );
      final effective = <String, InspectionPlant>{
        for (final row in stagedRows)
          row['id'] as String: InspectionPlant.fromJson(
            decodeInspectionJson(row['snapshot']),
          ),
      };
      final previous = <String, InspectionPlant>{
        for (final row in await txn.query('cached_plants'))
          row['id'] as String: InspectionPlant.fromJson(
            decodeInspectionJson(row['snapshot']),
          ),
      };
      await _overlayPendingChanges(txn, effective, previous);
      await _replacePlants(
        txn,
        effective.values,
        loadedAt: DateTime.parse(generation.single['loaded_at'] as String),
      );
      await txn.update(
        'cache_generations',
        {'is_complete': 1},
        where: 'generation_id = ?',
        whereArgs: [generationId],
      );
      await txn.delete(
        'staged_plants',
        where: 'generation_id = ?',
        whereArgs: [generationId],
      );
    });
    database.publishCommit();
  }

  Future<void> discardPlantStaging(String generationId) async {
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete(
        'staged_plants',
        where: 'generation_id = ?',
        whereArgs: [generationId],
      );
      await txn.delete(
        'cache_generations',
        where: 'generation_id = ? AND is_complete = 0',
        whereArgs: [generationId],
      );
    });
  }

  Future<List<Map<String, dynamic>>?> readFarmRows() =>
      _readReferenceRows(farmCacheKey, 'cached_farm', orderBy: 'sequence');

  Future<void> replaceFarmRows(List<Map<String, dynamic>> rows) =>
      _replaceOrderedReferenceRows(
        cacheKey: farmCacheKey,
        table: 'cached_farm',
        rows: rows,
      );

  Future<List<Map<String, dynamic>>?> readZoneRows() =>
      _readReferenceRows(zonesCacheKey, 'cached_zones', orderBy: 'sequence');

  Future<void> replaceZoneRows(List<Map<String, dynamic>> rows) async {
    final loadedAt = clock().toUtc();
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete('cached_zones');
      final batch = txn.batch();
      for (var index = 0; index < rows.length; index++) {
        final id = rows[index]['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('Zona remota sem identificador válido');
        }
        batch.insert('cached_zones', {
          'id': id,
          'sequence': index,
          'snapshot': jsonEncode(rows[index]),
        });
      }
      await batch.commit(noResult: true);
      await _writeCacheMetadata(txn, zonesCacheKey, loadedAt);
    });
  }

  Future<List<Map<String, dynamic>>?> readRegionRows(String zoneId) =>
      _readReferenceRows(
        _regionsCacheKey(zoneId),
        'cached_regions',
        where: 'zone_id = ?',
        whereArgs: [zoneId],
        orderBy: 'sequence',
      );

  Future<void> replaceRegionRows(
    String zoneId,
    List<Map<String, dynamic>> rows,
  ) async {
    final loadedAt = clock().toUtc();
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete(
        'cached_regions',
        where: 'zone_id = ?',
        whereArgs: [zoneId],
      );
      final batch = txn.batch();
      for (var index = 0; index < rows.length; index++) {
        batch.insert('cached_regions', {
          'zone_id': zoneId,
          'sequence': index,
          'snapshot': jsonEncode(rows[index]),
        });
      }
      await batch.commit(noResult: true);
      await _writeCacheMetadata(txn, _regionsCacheKey(zoneId), loadedAt);
    });
  }

  Future<List<Map<String, dynamic>>?> _readReferenceRows(
    String cacheKey,
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database.database;
    if (!await hasCompleteCache(cacheKey)) return null;
    final rows = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    return rows
        .map((row) => decodeInspectionJson(row['snapshot']))
        .toList(growable: false);
  }

  Future<void> _replaceOrderedReferenceRows({
    required String cacheKey,
    required String table,
    required List<Map<String, dynamic>> rows,
  }) async {
    final loadedAt = clock().toUtc();
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete(table);
      final batch = txn.batch();
      for (var index = 0; index < rows.length; index++) {
        batch.insert(table, {
          'sequence': index,
          'snapshot': jsonEncode(rows[index]),
        });
      }
      await batch.commit(noResult: true);
      await _writeCacheMetadata(txn, cacheKey, loadedAt);
    });
  }

  Future<void> _writeCacheMetadata(
    Transaction txn,
    String cacheKey,
    DateTime loadedAt, {
    CachedPlantTotals? plantTotals,
  }) {
    final values = {
      'cache_key': cacheKey,
      'loaded_at': loadedAt.toUtc().toIso8601String(),
      'is_complete': 1,
      'row_count': ?plantTotals?.rowCount,
      'existing_plants': ?plantTotals?.existingPlants,
      'available_planting_spots': ?plantTotals?.availablePlantingSpots,
    };
    return txn.insert(
      'cache_metadata',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static String _regionsCacheKey(String zoneId) => 'regions:$zoneId';

  Future<InspectionSnapshot?> readSnapshot() =>
      RuntimeDiagnostics.instance.track(RuntimeStage.localRead, _readSnapshot);

  Future<InspectionSnapshot?> _readSnapshot() async {
    final db = await database.database;
    return db.transaction((txn) async {
      final metadata = (await txn.query('installation')).single;
      if (metadata['loaded_at'] == null) return null;
      return InspectionSnapshot(
        plants: (await txn.query('cached_plants', orderBy: 'id'))
            .map(
              (r) =>
                  InspectionPlant.fromJson(decodeInspectionJson(r['snapshot'])),
            )
            .where((plant) => plant.eligible || plant.nonExistent)
            .toList(),
        types: (await txn.query(
          'occurrence_types',
          orderBy: 'name, id',
        )).map((r) => OccurrenceType.fromJson(r)).toList(),
        loadedAt: DateTime.parse(metadata['loaded_at'] as String),
      );
    });
  }

  Future<void> saveCatalog(List<OccurrenceType> types) async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final type in types) {
        await txn.insert(
          'occurrence_types',
          type.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await _writeCacheMetadata(txn, occurrenceTypesCacheKey, clock().toUtc());
    });
    database.publishCommit();
  }

  Future<List<OccurrenceType>?> readCachedCatalog() async {
    final catalog = await readCatalog();
    if (catalog.isNotEmpty || await hasCompleteCache(occurrenceTypesCacheKey)) {
      return catalog;
    }
    return null;
  }

  Future<List<OccurrenceType>> readCatalog() async =>
      (await (await database.database).query(
        'occurrence_types',
        orderBy: 'name, id',
      )).map((r) => OccurrenceType.fromJson(r)).toList();

  Future<void> replaceSnapshot(InspectionSnapshot snapshot) async {
    if (snapshot.types.isEmpty) {
      throw StateError(
        'Catálogo indisponível. Verifique o acesso e carregue novamente.',
      );
    }
    final db = await database.database;
    await db.transaction((txn) async {
      final effective = {for (final plant in snapshot.plants) plant.id: plant};
      final previous = {
        for (final row in await txn.query('cached_plants'))
          row['id'] as String: InspectionPlant.fromJson(
            decodeInspectionJson(row['snapshot']),
          ),
      };
      await _overlayPendingChanges(txn, effective, previous);
      // Keep retired types referenced by pending changes available for audit/editing.
      final batch = txn.batch();
      for (final type in snapshot.types) {
        batch.insert(
          'occurrence_types',
          type.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      await _writeCacheMetadata(
        txn,
        occurrenceTypesCacheKey,
        snapshot.loadedAt,
      );
      await _replacePlants(txn, effective.values, loadedAt: snapshot.loadedAt);
    });
    database.publishCommit();
  }

  Future<void> _overlayPendingChanges(
    Transaction txn,
    Map<String, InspectionPlant> effective,
    Map<String, InspectionPlant> previous,
  ) async {
    final syncedAdded = await txn.query(
      'local_added_plants',
      where: "sync_status = 'synced' AND remote_plant_id IS NOT NULL",
    );
    for (final row in syncedAdded) {
      final pId = row['remote_plant_id'] as String;
      if (!effective.containsKey(pId)) {
        effective[pId] = InspectionPlant(
          id: pId,
          latitude: (row['latitude'] as num).toDouble(),
          longitude: (row['longitude'] as num).toDouble(),
          nonExistent: (row['non_existent'] as int) == 1,
          zoneId: row['zone_id'] as String?,
          eligible: true,
        );
      }
    }
    final pending = await txn.rawQuery(
      '''SELECT c.* FROM local_inspection_changes c
      JOIN local_inspections i ON i.local_id = c.inspection_local_id
      WHERE i.sync_status != 'synced' ORDER BY i.rowid, c.sequence''',
    );
    for (final change in pending) {
      final id = change['plant_id'] as String;
      var plant = effective[id] ?? previous[id]?.withState({}, eligible: false);
      if (plant == null) throw StateError('Snapshot local incompleto');
      final types = {...plant.openTypeIds};
      if (change['change_type'] == 'add_occurrence') {
        types.add(change['occurrence_type_id'] as String);
      } else {
        types.remove(change['occurrence_type_id']);
      }
      effective[id] = plant.withState(types);
    }
    final pendingStatus = await txn.rawQuery(
      '''SELECT s.* FROM local_inspection_plant_status s
      JOIN local_inspections i ON i.local_id = s.inspection_local_id
      WHERE i.sync_status != 'synced' AND s.non_existent != s.initial_non_existent''',
    );
    for (final s in pendingStatus) {
      final id = s['plant_id'] as String;
      final plant = effective[id] ?? previous[id]?.withState({}, eligible: false);
      if (plant != null) {
        effective[id] = plant.withState(
          plant.openTypeIds,
          eligible: true,
          nonExistent: (s['non_existent'] as int) == 1,
        );
      }
    }
  }

  Future<void> _replacePlants(
    Transaction txn,
    Iterable<InspectionPlant> plants, {
    required DateTime loadedAt,
  }) async {
    await txn.delete('cached_plants');
    final batch = txn.batch();
    for (final plant in plants) {
      batch.insert('cached_plants', {
        'id': plant.id,
        'snapshot': jsonEncode(plant.toJson()),
      });
    }
    await batch.commit(noResult: true);
    await txn.update('installation', {
      'loaded_at': loadedAt.toUtc().toIso8601String(),
    });
    await _writeCacheMetadata(
      txn,
      plantsCacheKey,
      loadedAt,
      plantTotals: CachedPlantTotals.fromPlants(plants),
    );
    final draft = await _ensureDraft(txn);
    await _capturePlants(txn, draft);
  }

  Future<String> _ensureDraft(Transaction txn) async {
    final rows = await txn.query(
      'local_inspections',
      where: "state = 'in_progress'",
    );
    if (rows.isNotEmpty) return rows.single['local_id'] as String;
    final id = newId();
    await txn.insert('local_inspections', {
      'local_id': id,
      'started_at': clock().toUtc().toIso8601String(),
      'state': 'in_progress',
      'sync_status': 'pending',
    });
    await _capturePlants(txn, id);
    return id;
  }

  Future<void> _capturePlants(Transaction txn, String id) async {
    final rows = await txn.query('cached_plants');
    final batch = txn.batch();
    for (final row in rows) {
      final plant = InspectionPlant.fromJson(
        decodeInspectionJson(row['snapshot']),
      );
      if (!plant.eligible && !plant.nonExistent) continue;
      batch.insert('local_inspection_loaded_plants', {
        'inspection_local_id': id,
        'plant_id': plant.id,
        'snapshot': row['snapshot'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggle(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final metadata = (await txn.query('installation')).single;
      final rows = await txn.query(
        'cached_plants',
        where: 'id = ?',
        whereArgs: [plantId],
      );
      final type = await txn.query(
        'occurrence_types',
        where: 'id = ?',
        whereArgs: [typeId],
      );
      if (metadata['loaded_at'] == null || rows.isEmpty || type.isEmpty) {
        throw StateError(
          'Carregue o estado completo da planta antes de editar.',
        );
      }
      final plant = InspectionPlant.fromJson(
        decodeInspectionJson(rows.single['snapshot']),
      );
      if (!plant.eligible && !plant.nonExistent) {
        throw StateError('Planta indisponível para inspeção.');
      }
      final draftId = await _ensureDraft(txn);
      final draft = (await txn.query(
        'local_inspections',
        where: 'local_id = ?',
        whereArgs: [draftId],
      )).single;
      final sequence = (draft['last_sequence'] as int) + 1;
      var time = clock().toUtc();
      final last = draft['last_changed_at'] as String?;
      if (last != null && !time.isAfter(DateTime.parse(last))) {
        time = DateTime.parse(last).add(const Duration(microseconds: 1));
      }
      final loaded = await txn.query(
        'local_inspection_loaded_plants',
        where: 'inspection_local_id = ? AND plant_id = ?',
        whereArgs: [draftId, plantId],
      );
      if (loaded.isEmpty) {
        await txn.insert('local_inspection_loaded_plants', {
          'inspection_local_id': draftId,
          'plant_id': plantId,
          'snapshot': rows.single['snapshot'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final added = !plant.openTypeIds.contains(typeId);
      await txn.insert('local_inspection_changes', {
        'local_id': newId(),
        'inspection_local_id': draftId,
        'plant_id': plantId,
        'occurrence_type_id': typeId,
        'change_type': added ? 'add_occurrence' : 'remove_occurrence',
        'sequence': sequence,
        'changed_at': time.toIso8601String(),
        'latitude': location?.latitude,
        'longitude': location?.longitude,
        'accuracy': location?.accuracy,
        'distance': distance,
      });
      final selected = {...plant.openTypeIds};
      if (added) {
        selected.add(typeId);
      } else {
        selected.remove(typeId);
      }
      await txn.update(
        'cached_plants',
        {'snapshot': jsonEncode(plant.withState(selected).toJson())},
        where: 'id = ?',
        whereArgs: [plantId],
      );
      await txn.rawUpdate(
        '''UPDATE local_inspections SET last_sequence = ?, last_changed_at = ?,
        changes_count = changes_count + 1,
        plants_count = (SELECT COUNT(DISTINCT plant_id) FROM local_inspection_changes WHERE inspection_local_id = ?)
        WHERE local_id = ?''',
        [sequence, time.toIso8601String(), draftId, draftId],
      );
    });
    database.publishCommit();
  }

  Future<void> setPlantNonExistent(
    String plantId,
    bool nonExistent,
  ) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cached_plants',
        where: 'id = ?',
        whereArgs: [plantId],
      );
      if (rows.isEmpty) {
        throw StateError('Carregue o estado da planta antes de editar.');
      }
      final plant = InspectionPlant.fromJson(
        decodeInspectionJson(rows.single['snapshot']),
      );
      if (plant.nonExistent == nonExistent) return;

      final draftId = await _ensureDraft(txn);
      final draft = (await txn.query(
        'local_inspections',
        where: 'local_id = ?',
        whereArgs: [draftId],
      )).single;

      final statusRows = await txn.query(
        'local_inspection_plant_status',
        where: 'inspection_local_id = ? AND plant_id = ?',
        whereArgs: [draftId, plantId],
      );
      final bool initialNonExistent;
      if (statusRows.isNotEmpty) {
        initialNonExistent =
            (statusRows.single['initial_non_existent'] as int) == 1;
        await txn.update(
          'local_inspection_plant_status',
          {'non_existent': nonExistent ? 1 : 0},
          where: 'inspection_local_id = ? AND plant_id = ?',
          whereArgs: [draftId, plantId],
        );
      } else {
        initialNonExistent = plant.nonExistent;
        await txn.insert('local_inspection_plant_status', {
          'inspection_local_id': draftId,
          'plant_id': plantId,
          'non_existent': nonExistent ? 1 : 0,
          'initial_non_existent': initialNonExistent ? 1 : 0,
        });
      }

      final loaded = await txn.query(
        'local_inspection_loaded_plants',
        where: 'inspection_local_id = ? AND plant_id = ?',
        whereArgs: [draftId, plantId],
      );
      if (loaded.isEmpty) {
        await txn.insert('local_inspection_loaded_plants', {
          'inspection_local_id': draftId,
          'plant_id': plantId,
          'snapshot': rows.single['snapshot'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      var time = clock().toUtc();
      final last = draft['last_changed_at'] as String?;
      if (last != null && !time.isAfter(DateTime.parse(last))) {
        time = DateTime.parse(last).add(const Duration(microseconds: 1));
      }

      final updatedPlant = plant.withState(
        plant.openTypeIds,
        eligible: true,
        nonExistent: nonExistent,
      );
      await txn.update(
        'cached_plants',
        {'snapshot': jsonEncode(updatedPlant.toJson())},
        where: 'id = ?',
        whereArgs: [plantId],
      );

      final countRes = await txn.rawQuery(
        '''SELECT COUNT(DISTINCT plant_id) as count FROM (
          SELECT plant_id FROM local_inspection_changes WHERE inspection_local_id = ?
          UNION
          SELECT plant_id FROM local_inspection_plant_status
          WHERE inspection_local_id = ? AND non_existent != initial_non_existent
        )''',
        [draftId, draftId],
      );
      final modifiedPlantsCount = (countRes.single['count'] as int?) ?? 0;

      await txn.rawUpdate(
        '''UPDATE local_inspections SET last_changed_at = ?,
        changes_count = changes_count + 1,
        plants_count = ?
        WHERE local_id = ?''',
        [time.toIso8601String(), modifiedPlantsCount, draftId],
      );
    });
    database.publishCommit();
  }

  Future<LocalInspection?> finalize() async {
    final db = await database.database;
    return db.transaction((txn) async {
      final drafts = await txn.query(
        'local_inspections',
        where: "state = 'in_progress'",
      );
      if (drafts.isEmpty) return null;
      final draft = drafts.single;
      final id = draft['local_id'] as String;
      final rows = await txn.query(
        'local_inspection_changes',
        where: 'inspection_local_id = ?',
        whereArgs: [id],
        orderBy: 'sequence',
      );
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final change = _change(row);
        (grouped[change.plantId] ??= []).add(change.toPayload());
      }

      final statusRows = await txn.query(
        'local_inspection_plant_status',
        where: 'inspection_local_id = ? AND non_existent != initial_non_existent',
        whereArgs: [id],
      );
      final nonExistentChangedIds = {
        for (final r in statusRows) r['plant_id'] as String,
      };

      final allChangedPlantIds = <String>{...grouped.keys, ...nonExistentChangedIds};
      if (allChangedPlantIds.isEmpty) return null;

      final plantNonExistentMap = <String, bool>{
        for (final r in statusRows)
          r['plant_id'] as String: (r['non_existent'] as int) == 1,
      };

      for (final pId in grouped.keys) {
        if (!plantNonExistentMap.containsKey(pId)) {
          final cached = await txn.query(
            'cached_plants',
            where: 'id = ?',
            whereArgs: [pId],
          );
          if (cached.isNotEmpty) {
            final currP = InspectionPlant.fromJson(
              decodeInspectionJson(cached.single['snapshot']),
            );
            plantNonExistentMap[pId] = currP.nonExistent;
          } else {
            plantNonExistentMap[pId] = false;
          }
        }
      }

      var finished = clock().toUtc();
      final lastStr = draft['last_changed_at'] as String?;
      if (lastStr != null) {
        final last = DateTime.parse(lastStr);
        if (finished.isBefore(last)) finished = last;
      }
      final previous = await txn.rawQuery(
        'SELECT finished_at FROM local_inspections WHERE finished_at IS NOT NULL ORDER BY rowid DESC LIMIT 1',
      );
      if (previous.isNotEmpty) {
        final previousTime = DateTime.parse(
          previous.single['finished_at'] as String,
        );
        if (!finished.isAfter(previousTime)) {
          finished = previousTime.add(const Duration(microseconds: 1));
        }
      }
      final device = (await txn.query('installation')).single['device_id'];
      final payload = jsonEncode({
        'deviceId': device,
        'localInspectionId': id,
        'startedAt': draft['started_at'],
        'finishedAt': finished.toIso8601String(),
        'zoneId': null,
        'occurrenceTypeId': null,
        'plantsChanged': [
          for (final pId in allChangedPlantIds)
            {
              'plantId': pId,
              'nonExistent': plantNonExistentMap[pId] ?? false,
              'changes': grouped[pId] ?? const <Map<String, dynamic>>[],
            },
        ],
      });
      await txn.update(
        'local_inspections',
        {
          'finished_at': finished.toIso8601String(),
          'state': 'finished',
          'payload': payload,
        },
        where: 'local_id = ?',
        whereArgs: [id],
      );
      return _inspection(
        (await txn.query(
          'local_inspections',
          where: 'local_id = ?',
          whereArgs: [id],
        )).single,
      );
    });
  }

  Future<List<LocalInspection>> list() async =>
      (await (await database.database).query(
        'local_inspections',
        orderBy: 'rowid DESC',
      )).map(_inspection).toList();
  Future<List<LocalInspection>> pending() async =>
      (await (await database.database).query(
        'local_inspections',
        where: "state = 'finished' AND sync_status != 'synced'",
        orderBy: 'rowid',
      )).map(_inspection).toList();
  Future<List<InspectionChange>> changes(String id) async =>
      (await (await database.database).query(
        'local_inspection_changes',
        where: 'inspection_local_id = ?',
        whereArgs: [id],
        orderBy: 'sequence',
      )).map(_change).toList();

  Future<AddedInspectionPlant> addPlant({
    required double latitude,
    required double longitude,
    required bool nonExistent,
    String? zoneId,
  }) async {
    final plant = AddedInspectionPlant(
      localId: newId(),
      latitude: latitude,
      longitude: longitude,
      nonExistent: nonExistent,
      status: InspectionSyncStatus.pending,
      createdAt: clock().toUtc(),
      zoneId: zoneId,
    );
    if (!plant.hasValidCoordinates) {
      throw ArgumentError.value(
        {'latitude': latitude, 'longitude': longitude},
        'coordinates',
        'Coordenadas invalidas para planta adicionada',
      );
    }
    await (await database.database).insert('local_added_plants', {
      'local_id': plant.localId,
      'latitude': plant.latitude,
      'longitude': plant.longitude,
      'non_existent': plant.nonExistent ? 1 : 0,
      'zone_id': plant.zoneId,
      'sync_status': plant.status.name,
      'created_at': plant.createdAt.toIso8601String(),
    });
    database.publishCommit();
    return plant;
  }

  Future<List<AddedInspectionPlant>> listAddedPlants() async =>
      (await (await database.database).query(
        'local_added_plants',
        orderBy: 'created_at DESC, local_id DESC',
      )).map(_addedPlant).toList();

  Future<List<AddedInspectionPlant>> pendingAddedPlants() async =>
      (await (await database.database).query(
        'local_added_plants',
        where: "sync_status IN ('pending', 'error')",
        orderBy: 'created_at, local_id',
      )).map(_addedPlant).toList();

  Future<void> removeAddedPlant(String localId) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'local_added_plants',
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      if (rows.isNotEmpty) {
        final remotePlantId = rows.first['remote_plant_id'] as String?;
        if (remotePlantId != null) {
          await txn.delete(
            'cached_plants',
            where: 'id = ?',
            whereArgs: [remotePlantId],
          );
        }
      }
      await txn.delete(
        'local_added_plants',
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
    database.publishCommit();
  }

  Future<void> markAddedPlantsSyncing(List<String> localIds) async {
    if (localIds.isEmpty) return;
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in localIds) {
        await txn.update(
          'local_added_plants',
          {'sync_status': 'syncing', 'error': null},
          where: "local_id = ? AND sync_status IN ('pending', 'error')",
          whereArgs: [id],
        );
      }
    });
    database.publishCommit();
  }

  Future<void> markAddedPlantError(String localId, Object error) async {
    final formatted = _formatSyncError(error);
    await (await database.database).update(
      'local_added_plants',
      {
        'sync_status': formatted == 'Sem internet' ? 'pending' : 'error',
        'error': formatted,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    database.publishCommit();
  }

  Future<void> acknowledgeAddedPlants(
    List<AddedPlantSyncResult> results,
  ) async {
    if (results.isEmpty) return;
    final db = await database.database;
    await db.transaction((txn) async {
      final now = clock().toUtc().toIso8601String();
      final metadata = (await txn.query('installation')).single;
      if (metadata['loaded_at'] == null) {
        await txn.update('installation', {'loaded_at': now});
      }

      final activeDrafts = await txn.query(
        'local_inspections',
        columns: ['local_id'],
        where: "state = 'in_progress'",
      );

      for (final result in results) {
        await txn.update(
          'local_added_plants',
          {
            'sync_status': InspectionSyncStatus.synced.name,
            'remote_plant_id': result.plantId,
            if (result.zoneId != null) 'zone_id': result.zoneId,
            'synced_at': now,
            'error': null,
          },
          where: 'local_id = ?',
          whereArgs: [result.localId],
        );

        final plant = InspectionPlant(
          id: result.plantId,
          latitude: result.latitude,
          longitude: result.longitude,
          zoneId: result.zoneId,
          nonExistent: result.nonExistent,
          eligible: true,
        );
        final plantJson = jsonEncode(plant.toJson());

        await txn.insert(
          'cached_plants',
          {
            'id': result.plantId,
            'snapshot': plantJson,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final draft in activeDrafts) {
          final draftId = draft['local_id'] as String;
          await txn.insert(
            'local_inspection_loaded_plants',
            {
              'inspection_local_id': draftId,
              'plant_id': result.plantId,
              'snapshot': plantJson,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
    database.publishCommit();
  }

  Future<void> markSyncing(String id) async {
    await (await database.database).update(
      'local_inspections',
      {'sync_status': 'syncing', 'error': null},
      where: 'local_id = ? AND state = ?',
      whereArgs: [id, 'finished'],
    );
  }

  Future<void> markError(String id, Object error) async {
    final formatted = _formatSyncError(error);
    final syncStatus = formatted == 'Sem internet' ? 'pending' : 'error';
    await (await database.database).update(
      'local_inspections',
      {'sync_status': syncStatus, 'error': formatted},
      where: 'local_id = ?',
      whereArgs: [id],
    );
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
        await txn.update(
          'local_inspections',
          {
            'state': 'synced',
            'sync_status': 'synced',
            'remote_id': result.operationId,
            'synced_at': now,
            'error': null,
          },
          where: 'local_id = ?',
          whereArgs: [id],
        );

        await txn.update(
          'local_inspection_changes',
          {'sync_status': 'synced'},
          where: 'inspection_local_id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> removePlantFromInspection(
    String inspectionId,
    String plantId,
  ) async {
    final db = await database.database;
    await db.transaction((txn) async {
      // 1. Delete changes for this plant in this inspection
      await txn.delete(
        'local_inspection_changes',
        where: 'inspection_local_id = ? AND plant_id = ?',
        whereArgs: [inspectionId, plantId],
      );
      await txn.delete(
        'local_inspection_plant_status',
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
        final plant = InspectionPlant.fromJson(
          decodeInspectionJson(loaded.single['snapshot']),
        );
        final remainingPlantChanges = await txn.rawQuery(
          '''
          SELECT c.* FROM local_inspection_changes c
          JOIN local_inspections i ON i.local_id = c.inspection_local_id
          WHERE c.plant_id = ? AND i.sync_status != 'synced'
          ORDER BY i.rowid, c.sequence
        ''',
          [plantId],
        );
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

      final countRes = await txn.rawQuery(
        '''SELECT COUNT(DISTINCT plant_id) as count FROM (
          SELECT plant_id FROM local_inspection_changes WHERE inspection_local_id = ?
          UNION
          SELECT plant_id FROM local_inspection_plant_status
          WHERE inspection_local_id = ? AND non_existent != initial_non_existent
        )''',
        [inspectionId, inspectionId],
      );
      final remainingChangesCount = remainingRows.length;
      final remainingPlantsCount = (countRes.single['count'] as int?) ?? 0;

      if (remainingPlantsCount == 0) {
        // Remove all traces of the inspection if no plants remain
        await txn.delete(
          'local_inspection_changes',
          where: 'inspection_local_id = ?',
          whereArgs: [inspectionId],
        );
        await txn.delete(
          'local_inspection_plant_status',
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
              final payloadMap = Map<String, dynamic>.from(
                jsonDecode(newPayload) as Map,
              );
              final plantsChanged =
                  (payloadMap['plantsChanged'] as List<dynamic>? ?? [])
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
    database.publishCommit();
  }

  static LocalInspection _inspection(Map<String, Object?> r) => LocalInspection(
    id: r['local_id'] as String,
    startedAt: DateTime.parse(r['started_at'] as String),
    finishedAt: r['finished_at'] == null
        ? null
        : DateTime.parse(r['finished_at'] as String),
    status: InspectionSyncStatus.values.byName(r['sync_status'] as String),
    plantsCount: r['plants_count'] as int,
    changesCount: r['changes_count'] as int,
    error: r['error'] as String?,
    remoteId: r['remote_id'] as String?,
    payloadJson: r['payload'] as String?,
    syncedAt: r['synced_at'] == null
        ? null
        : DateTime.parse(r['synced_at'] as String),
  );
  static InspectionChange _change(Map<String, Object?> r) => InspectionChange(
    id: r['local_id'] as String,
    plantId: r['plant_id'] as String,
    typeId: r['occurrence_type_id'] as String,
    added: r['change_type'] == 'add_occurrence',
    sequence: r['sequence'] as int,
    changedAt: DateTime.parse(r['changed_at'] as String),
    latitude: (r['latitude'] as num?)?.toDouble(),
    longitude: (r['longitude'] as num?)?.toDouble(),
    accuracy: (r['accuracy'] as num?)?.toDouble(),
    distance: (r['distance'] as num?)?.toDouble(),
  );
  static AddedInspectionPlant _addedPlant(Map<String, Object?> r) =>
      AddedInspectionPlant(
        localId: r['local_id'] as String,
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
        nonExistent: (r['non_existent'] as int) == 1,
        status: InspectionSyncStatus.values.byName(r['sync_status'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        zoneId: r['zone_id'] as String?,
        error: r['error'] as String?,
        remotePlantId: r['remote_plant_id'] as String?,
        syncedAt: r['synced_at'] == null
            ? null
            : DateTime.parse(r['synced_at'] as String),
      );

  static String _formatSyncError(Object error) {
    final str = error.toString();
    final lower = str.toLowerCase();
    final isNetwork =
        lower.contains('sem internet') ||
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
    return isNetwork ? 'Sem internet' : str;
  }
}

class CachedPlantTotals {
  const CachedPlantTotals({
    required this.rowCount,
    required this.existingPlants,
    required this.availablePlantingSpots,
  });

  factory CachedPlantTotals.fromPlants(Iterable<InspectionPlant> plants) {
    var rowCount = 0;
    var existingPlants = 0;
    var availablePlantingSpots = 0;
    for (final plant in plants) {
      rowCount++;
      if (plant.nonExistent) {
        availablePlantingSpots++;
      } else if (plant.eligible) {
        existingPlants++;
      }
    }
    return CachedPlantTotals(
      rowCount: rowCount,
      existingPlants: existingPlants,
      availablePlantingSpots: availablePlantingSpots,
    );
  }

  final int rowCount;
  final int existingPlants;
  final int availablePlantingSpots;
}
