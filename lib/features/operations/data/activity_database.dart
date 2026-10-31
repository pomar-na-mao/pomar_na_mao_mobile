import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ActivityDatabase {
  ActivityDatabase({required this.projectUrl, this.factory, this.directory});

  final String projectUrl;
  final DatabaseFactory? factory;
  final String? directory;
  Future<Database>? _opening;
  bool _closed = false;

  Future<Database> get database {
    if (_closed) throw StateError('Banco da Atividade fechado');
    return _opening ??= _open().catchError((Object error) {
      _opening = null;
      throw error;
    });
  }

  Future<Database> _open() async {
    final resolvedFactory = factory ?? databaseFactory;
    final project = Uri.parse(projectUrl).origin;
    final fileId = const Uuid().v5(Namespace.url.value, project);
    final root = directory ?? await resolvedFactory.getDatabasesPath();
    final databasePath = p.join(root, 'activity_$fileId.db');
    await _moveLegacyDatabase(
      resolvedFactory,
      p.join(root, 'field_notebook_$fileId.db'),
      databasePath,
    );
    final db = await resolvedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final sql in _schema) {
            await db.execute(sql);
          }
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            for (final sql in _legacyRenameSchema) {
              await db.execute(sql);
            }
          }
          if (oldVersion < 3) {
            for (final sql in _mixtureSchema) {
              await db.execute(sql);
            }
          }
          if (oldVersion < 4) {
            for (final sql in _machineSchema) {
              await db.execute(sql);
            }
          }
        },
      ),
    );
    try {
      await db.transaction((txn) async {
        final installations = await txn.query('installation');
        if (installations.isEmpty) {
          await txn.insert('installation', {
            'id': 1,
            'project_url': project,
            'device_id': const Uuid().v4(),
          });
        } else if (installations.single['project_url'] != project) {
          throw StateError('O banco pertence a outro projeto');
        }
        await txn.update('local_activity_entries', {
          'sync_status': 'pending',
        }, where: "sync_status = 'syncing'");
      });
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<void> _moveLegacyDatabase(
    DatabaseFactory factory,
    String legacyPath,
    String activityPath,
  ) async {
    if (await factory.databaseExists(activityPath) ||
        !await factory.databaseExists(legacyPath)) {
      return;
    }
    await File(legacyPath).rename(activityPath);
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final legacySidecar = File('$legacyPath$suffix');
      if (await legacySidecar.exists()) {
        await legacySidecar.rename('$activityPath$suffix');
      }
    }
  }

  Future<String> get deviceId async =>
      (await (await database).query('installation')).single['device_id']
          as String;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  static const _schema = <String>[
    '''CREATE TABLE installation (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      project_url TEXT NOT NULL,
      device_id TEXT NOT NULL)''',
    '''CREATE TABLE local_activity_entries (
      local_id TEXT PRIMARY KEY,
      geometry_type TEXT NOT NULL CHECK(geometry_type IN ('route','area')),
      geometry_geojson TEXT NOT NULL,
      activity TEXT NOT NULL CHECK(length(trim(activity)) BETWEEN 1 AND 200),
      performed_at TEXT NOT NULL,
      responsible TEXT NOT NULL CHECK(length(trim(responsible)) BETWEEN 1 AND 160),
      mixture_id TEXT,
      mixture_name_snapshot TEXT,
      machine_id TEXT,
      machine_name_snapshot TEXT,
      machine_brand_snapshot TEXT,
      payload_fingerprint TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending'
        CHECK(sync_status IN ('pending','syncing','error','synced')),
      error TEXT,
      remote_field_operation_id TEXT,
      remote_entry_id TEXT,
      synced_at TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
    '''CREATE TABLE local_activity_entry_inputs (
      local_id TEXT PRIMARY KEY,
      entry_local_id TEXT NOT NULL REFERENCES local_activity_entries(local_id) ON DELETE CASCADE,
      input_id TEXT NOT NULL,
      name_snapshot TEXT NOT NULL,
      active_ingredient_snapshot TEXT,
      label_dose_snapshot TEXT,
      dose_unit_snapshot TEXT,
      applied_dose TEXT NOT NULL CHECK(length(trim(applied_dose)) BETWEEN 1 AND 200),
      UNIQUE(entry_local_id, input_id))''',
    '''CREATE INDEX local_activity_queue
      ON local_activity_entries(sync_status, performed_at)''',
    '''CREATE INDEX local_activity_inputs_entry
      ON local_activity_entry_inputs(entry_local_id)''',
  ];

  static const _legacyRenameSchema = <String>[
    'ALTER TABLE local_field_notebook_entries RENAME TO local_activity_entries',
    'ALTER TABLE local_field_notebook_entry_inputs RENAME TO local_activity_entry_inputs',
    'DROP INDEX IF EXISTS local_field_notebook_queue',
    'DROP INDEX IF EXISTS local_field_notebook_inputs_entry',
    '''CREATE INDEX IF NOT EXISTS local_activity_queue
      ON local_activity_entries(sync_status, performed_at)''',
    '''CREATE INDEX IF NOT EXISTS local_activity_inputs_entry
      ON local_activity_entry_inputs(entry_local_id)''',
  ];

  static const _mixtureSchema = <String>[
    'ALTER TABLE local_activity_entries ADD COLUMN mixture_id TEXT',
    'ALTER TABLE local_activity_entries ADD COLUMN mixture_name_snapshot TEXT',
  ];

  static const _machineSchema = <String>[
    'ALTER TABLE local_activity_entries ADD COLUMN machine_id TEXT',
    'ALTER TABLE local_activity_entries ADD COLUMN machine_name_snapshot TEXT',
    'ALTER TABLE local_activity_entries ADD COLUMN machine_brand_snapshot TEXT',
  ];
}
