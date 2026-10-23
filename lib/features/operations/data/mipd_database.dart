import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class MipdDatabase {
  MipdDatabase({required this.projectUrl, this.factory, this.directory});

  final String projectUrl;
  final DatabaseFactory? factory;
  final String? directory;
  Future<Database>? _opening;
  bool _closed = false;

  Future<Database> get database {
    if (_closed) throw StateError('Banco MIPD fechado');
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
    final db = await resolvedFactory.openDatabase(
      p.join(root, 'mipd_$fileId.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final sql in _schema) {
            await db.execute(sql);
          }
        },
      ),
    );
    await db.transaction((txn) async {
      final installations = await txn.query('installation');
      if (installations.isEmpty) {
        await txn.insert('installation', {
          'id': 1,
          'project_url': project,
          'device_id': const Uuid().v4(),
        });
      } else if (installations.single['project_url'] != project) {
        throw StateError('O banco MIPD pertence a outro projeto');
      }
      await txn.update('local_mipd_markings', {
        'sync_status': 'pending',
      }, where: "sync_status = 'syncing'");
    });
    return db;
  }

  Future<String> get deviceId async =>
      (await (await database).query('installation')).single['device_id']
          as String;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final opening = _opening;
    if (opening != null) await (await opening).close();
  }

  static const _schema = <String>[
    '''CREATE TABLE installation (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      project_url TEXT NOT NULL,
      device_id TEXT NOT NULL)''',
    '''CREATE TABLE local_mipd_markings (
      local_id TEXT PRIMARY KEY,
      plant_id TEXT NOT NULL,
      occurrence_type_id TEXT NOT NULL,
      plant_parts TEXT NOT NULL,
      observed_at TEXT NOT NULL,
      local_photo_path TEXT,
      remote_photo_path TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending'
        CHECK(sync_status IN ('pending','syncing','error','synced')),
      error TEXT,
      remote_operation_id TEXT,
      remote_occurrence_id TEXT,
      remote_marking_id TEXT,
      synced_at TEXT)''',
    '''CREATE INDEX local_mipd_queue
      ON local_mipd_markings(sync_status, observed_at)''',
    '''CREATE INDEX local_mipd_plant
      ON local_mipd_markings(plant_id, observed_at)''',
  ];
}
