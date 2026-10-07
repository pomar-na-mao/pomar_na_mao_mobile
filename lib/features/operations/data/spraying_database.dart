import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/diagnostics/runtime_diagnostics.dart';

class SprayingDatabase {
  SprayingDatabase({required this.projectUrl, this.factory, this.directory});

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
    if (_closed) throw StateError('Banco de pulverização fechado');
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
      p.join(root, 'spraying_$fileId.db'),
      options: OpenDatabaseOptions(
        version: 1,
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

        // Reset any operation left in syncing state back to reviewed
        await txn.update('local_spraying_operations', {
          'sync_status': 'reviewed',
        }, where: "sync_status = 'syncing'");
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
  }

  Future<String> get deviceId async => (await (await database).query(
    'installation',
    columns: ['device_id'],
  )).single['device_id'] as String;

  Future<void> close() async {
    _closed = true;
    final current = _opening;
    _opening = null;
    if (current != null) {
      final db = await current;
      await db.close();
    }
    await _changes.close();
  }

  static const _versionOne = [
    '''CREATE TABLE installation (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      project_url TEXT NOT NULL,
      device_id TEXT NOT NULL
    )''',
    '''CREATE TABLE local_spraying_operations (
      local_id TEXT PRIMARY KEY,
      zone_id TEXT NOT NULL,
      operator_name TEXT NOT NULL,
      started_at TEXT NOT NULL,
      finished_at TEXT NOT NULL,
      title TEXT,
      machine_name TEXT,
      tractor_identifier TEXT,
      notes TEXT,
      session_state TEXT NOT NULL DEFAULT 'finished',
      sync_status TEXT NOT NULL DEFAULT 'draft',
      remote_field_operation_id TEXT,
      synced_at TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )''',
    '''CREATE TABLE local_spraying_routes (
      local_id TEXT PRIMARY KEY,
      operation_local_id TEXT NOT NULL REFERENCES local_spraying_operations(local_id) ON DELETE CASCADE,
      geojson TEXT NOT NULL,
      distance_meters REAL NOT NULL DEFAULT 0.0,
      started_at TEXT NOT NULL,
      finished_at TEXT NOT NULL
    )''',
    '''CREATE TABLE local_spraying_track_points (
      local_id TEXT PRIMARY KEY,
      operation_local_id TEXT NOT NULL REFERENCES local_spraying_operations(local_id) ON DELETE CASCADE,
      recorded_at TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      speed_mps REAL,
      accuracy_m REAL
    )''',
    '''CREATE TABLE local_spraying_inputs (
      local_id TEXT PRIMARY KEY,
      operation_local_id TEXT NOT NULL REFERENCES local_spraying_operations(local_id) ON DELETE CASCADE,
      input_type TEXT NOT NULL,
      product_name TEXT NOT NULL,
      active_ingredient TEXT,
      dose REAL,
      dose_unit TEXT,
      total_quantity REAL,
      total_quantity_unit TEXT,
      notes TEXT
    )''',
    '''CREATE TABLE local_spraying_confirmed_plants (
      local_id TEXT PRIMARY KEY,
      operation_local_id TEXT NOT NULL REFERENCES local_spraying_operations(local_id) ON DELETE CASCADE,
      plant_id TEXT NOT NULL,
      match_source TEXT NOT NULL,
      matched_at TEXT,
      nearest_track_point_local_id TEXT,
      distance_meters REAL,
      notes TEXT
    )''',
    '''CREATE INDEX idx_spraying_track_points_op
       ON local_spraying_track_points (operation_local_id)''',
    '''CREATE INDEX idx_spraying_routes_op
       ON local_spraying_routes (operation_local_id)''',
    '''CREATE INDEX idx_spraying_inputs_op
       ON local_spraying_inputs (operation_local_id)''',
    '''CREATE INDEX idx_spraying_confirmed_plants_op
       ON local_spraying_confirmed_plants (operation_local_id)''',
    '''CREATE INDEX idx_spraying_operations_sync
       ON local_spraying_operations (sync_status)''',
  ];
}
