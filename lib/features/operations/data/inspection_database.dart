import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/diagnostics/runtime_diagnostics.dart';

class InspectionDatabase {
  InspectionDatabase({required this.projectUrl, this.factory, this.directory});

  final String projectUrl;
  final DatabaseFactory? factory;
  final String? directory;
  Future<Database>? _opening;
  bool _closed = false;
  int _revision = 0;
  int get revision => _revision;
  final _changes = StreamController<int>.broadcast(sync: true);
  Stream<int> get changes => _changes.stream;

  void publishCommit() {
    _revision++;
    if (!_changes.isClosed) _changes.add(_revision);
    RuntimeDiagnostics.instance.record(
      RuntimeStage.publication,
      revision: _revision,
    );
  }

  Future<Database> get database {
    if (_closed) throw StateError('Banco de inspeção fechado');
    return _opening ??= RuntimeDiagnostics.instance
        .track(RuntimeStage.databaseOpen, _open)
        .catchError((Object error) {
          _opening = null;
          throw error;
        });
  }

  Future<Database> _open() async {
    final resolvedFactory = factory ?? databaseFactory;
    final project = Uri.parse(projectUrl).origin;
    final fileId = const Uuid().v5(Namespace.url.value, project);
    final root = directory ?? await resolvedFactory.getDatabasesPath();
    final db = await resolvedFactory.openDatabase(
      p.join(root, 'inspections_$fileId.db'),
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    try {
      await db.transaction((txn) async {
        final metadata = await txn.query('installation');
        if (metadata.isEmpty) {
          await txn.insert('installation', {
            'id': 1,
            'project_url': project,
            'device_id': const Uuid().v4(),
          });
        } else if (metadata.single['project_url'] != project) {
          throw StateError('O banco pertence a outro projeto');
        }
        await txn.update('local_inspections', {
          'sync_status': 'pending',
        }, where: "sync_status = 'syncing'");
        await txn.delete('staged_plants');
        await txn.delete('cache_generations');
        await txn.execute('''CREATE TABLE IF NOT EXISTS local_inspection_plant_status (
          inspection_local_id TEXT NOT NULL REFERENCES local_inspections(local_id) ON DELETE CASCADE,
          plant_id TEXT NOT NULL,
          non_existent INTEGER NOT NULL DEFAULT 0,
          initial_non_existent INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(inspection_local_id, plant_id))''');
      });
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      for (final sql in _versionOne) {
        await db.execute(sql);
      }
    }
    if (oldVersion < 2) {
      for (final sql in _versionTwo) {
        await db.execute(sql);
      }
      await db.execute('''
        INSERT OR IGNORE INTO cache_metadata(cache_key, loaded_at, is_complete)
        SELECT 'occurrence_types', COALESCE(loaded_at, CURRENT_TIMESTAMP), 1
        FROM installation
        WHERE EXISTS (SELECT 1 FROM occurrence_types)
      ''');
    }
    if (oldVersion < 3) {
      for (final sql in _versionThree) {
        await db.execute(sql);
      }
    }
    if (oldVersion < 4) {
      for (final sql in _versionFour) {
        await db.execute(sql);
      }
    }
    if (oldVersion < 5) {
      for (final sql in _versionFive) {
        await db.execute(sql);
      }
    }
  }

  Future<String> get deviceId async =>
      (await (await database).query('installation')).single['device_id']
          as String;

  Future<void> close() async {
    _closed = true;
    final opening = _opening;
    if (opening != null) await (await opening).close();
    await _changes.close();
  }

  static const _versionOne = [
    '''CREATE TABLE installation (id INTEGER PRIMARY KEY CHECK(id = 1),
      project_url TEXT NOT NULL, device_id TEXT NOT NULL, loaded_at TEXT)''',
    '''CREATE TABLE occurrence_types (id TEXT PRIMARY KEY, name TEXT NOT NULL, code TEXT NOT NULL)''',
    '''CREATE TABLE cached_plants (id TEXT PRIMARY KEY, snapshot TEXT NOT NULL)''',
    '''CREATE TABLE local_inspections (
      local_id TEXT PRIMARY KEY, started_at TEXT NOT NULL, finished_at TEXT,
      state TEXT NOT NULL CHECK(state IN ('in_progress','finished','synced')),
      sync_status TEXT NOT NULL CHECK(sync_status IN ('pending','syncing','error','synced')),
      plants_count INTEGER NOT NULL DEFAULT 0, changes_count INTEGER NOT NULL DEFAULT 0,
      last_sequence INTEGER NOT NULL DEFAULT 0, last_changed_at TEXT,
      payload TEXT, error TEXT, remote_id TEXT, synced_at TEXT,
      CHECK((state = 'in_progress' AND finished_at IS NULL AND payload IS NULL)
        OR (state != 'in_progress' AND finished_at IS NOT NULL AND payload IS NOT NULL)))''',
    "CREATE UNIQUE INDEX single_active_inspection ON local_inspections(state) WHERE state = 'in_progress'",
    'CREATE INDEX inspection_queue ON local_inspections(sync_status, finished_at)',
    '''CREATE TABLE local_inspection_loaded_plants (
      inspection_local_id TEXT NOT NULL REFERENCES local_inspections(local_id),
      plant_id TEXT NOT NULL, snapshot TEXT NOT NULL,
      PRIMARY KEY(inspection_local_id, plant_id))''',
    '''CREATE TABLE local_inspection_changes (
      local_id TEXT PRIMARY KEY,
      inspection_local_id TEXT NOT NULL REFERENCES local_inspections(local_id),
      plant_id TEXT NOT NULL, occurrence_type_id TEXT NOT NULL,
      change_type TEXT NOT NULL CHECK(change_type IN ('add_occurrence','remove_occurrence')),
      sequence INTEGER NOT NULL, changed_at TEXT NOT NULL,
      latitude REAL, longitude REAL, accuracy REAL, distance REAL,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK(sync_status IN ('pending','synced')),
      UNIQUE(inspection_local_id, sequence), UNIQUE(inspection_local_id, changed_at),
      FOREIGN KEY(inspection_local_id, plant_id)
        REFERENCES local_inspection_loaded_plants(inspection_local_id, plant_id))''',
    'CREATE INDEX changes_plant ON local_inspection_changes(inspection_local_id, plant_id, sequence)',
  ];

  static const _versionTwo = [
    '''CREATE TABLE cache_metadata (
      cache_key TEXT PRIMARY KEY,
      loaded_at TEXT NOT NULL,
      is_complete INTEGER NOT NULL DEFAULT 1 CHECK(is_complete IN (0, 1)))''',
    '''CREATE TABLE cached_farm (
      sequence INTEGER PRIMARY KEY,
      snapshot TEXT NOT NULL)''',
    '''CREATE TABLE cached_zones (
      id TEXT PRIMARY KEY,
      sequence INTEGER NOT NULL,
      snapshot TEXT NOT NULL)''',
    'CREATE INDEX cached_zones_sequence ON cached_zones(sequence)',
    '''CREATE TABLE cached_regions (
      zone_id TEXT NOT NULL,
      sequence INTEGER NOT NULL,
      snapshot TEXT NOT NULL,
      PRIMARY KEY(zone_id, sequence))''',
  ];

  static const _versionThree = [
    'ALTER TABLE cache_metadata ADD COLUMN row_count INTEGER',
    'ALTER TABLE cache_metadata ADD COLUMN existing_plants INTEGER',
    'ALTER TABLE cache_metadata ADD COLUMN available_planting_spots INTEGER',
  ];

  static const _versionFour = [
    '''CREATE TABLE cache_generations (
      generation_id TEXT PRIMARY KEY,
      cache_key TEXT NOT NULL,
      started_at TEXT NOT NULL,
      loaded_at TEXT NOT NULL,
      row_count INTEGER NOT NULL DEFAULT 0,
      existing_plants INTEGER NOT NULL DEFAULT 0,
      available_planting_spots INTEGER NOT NULL DEFAULT 0,
      is_complete INTEGER NOT NULL DEFAULT 0 CHECK(is_complete IN (0, 1)))''',
    '''CREATE TABLE staged_plants (
      generation_id TEXT NOT NULL REFERENCES cache_generations(generation_id)
        ON DELETE CASCADE,
      id TEXT NOT NULL,
      snapshot TEXT NOT NULL,
      PRIMARY KEY(generation_id, id))''',
    'CREATE INDEX staged_plants_generation ON staged_plants(generation_id)',
  ];

  static const _versionFive = [
    '''CREATE TABLE IF NOT EXISTS local_inspection_plant_status (
      inspection_local_id TEXT NOT NULL REFERENCES local_inspections(local_id) ON DELETE CASCADE,
      plant_id TEXT NOT NULL,
      non_existent INTEGER NOT NULL DEFAULT 0,
      initial_non_existent INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(inspection_local_id, plant_id))''',
  ];
}

Map<String, dynamic> decodeInspectionJson(Object? value) =>
    jsonDecode(value as String) as Map<String, dynamic>;
