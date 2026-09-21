import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final ffiFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspection_db_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'creates tables, indices, and persists deviceId across reopens',
    () async {
      final db1 = InspectionDatabase(
        projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
        factory: ffiFactory,
        directory: tempDir.path,
      );

      final deviceId1 = await db1.deviceId;
      expect(deviceId1, isNotEmpty);

      final rawDb1 = await db1.database;
      final tables = await rawDb1.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(
        tableNames,
        containsAll({
          'installation',
          'occurrence_types',
          'cached_plants',
          'cache_metadata',
          'cached_farm',
          'cached_zones',
          'cached_regions',
          'local_inspections',
          'local_inspection_loaded_plants',
          'local_inspection_changes',
        }),
      );

      await db1.close();

      // Reopen with same directory and url
      final db2 = InspectionDatabase(
        projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
        factory: ffiFactory,
        directory: tempDir.path,
      );

      final deviceId2 = await db2.deviceId;
      expect(deviceId2, equals(deviceId1));
      await db2.close();
    },
  );

  test('recovers syncing state to pending upon reopening', () async {
    final db = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );

    final rawDb = await db.database;
    await rawDb.insert('local_inspections', {
      'local_id': 'inspect-1',
      'started_at': '2026-09-18T20:00:00.000Z',
      'finished_at': '2026-09-18T20:05:00.000Z',
      'state': 'finished',
      'sync_status': 'syncing',
      'plants_count': 1,
      'changes_count': 1,
      'last_sequence': 1,
      'last_changed_at': '2026-09-18T20:05:00.000Z',
      'payload': '{"test":true}',
    });

    await db.close();

    final reopened = InspectionDatabase(
      projectUrl: 'https://uxschjkypkkzprbwuhxm.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );

    final reopenedRaw = await reopened.database;
    final row = (await reopenedRaw.query(
      'local_inspections',
      where: 'local_id = ?',
      whereArgs: ['inspect-1'],
    )).single;

    expect(row['sync_status'], 'pending');
    await reopened.close();
  });

  test('isolates different projects into different database files', () async {
    final dbA = InspectionDatabase(
      projectUrl: 'https://project-a.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );
    final dbB = InspectionDatabase(
      projectUrl: 'https://project-b.supabase.co',
      factory: ffiFactory,
      directory: tempDir.path,
    );

    final deviceA = await dbA.deviceId;
    final deviceB = await dbB.deviceId;

    expect(deviceA, isNot(equals(deviceB)));

    await dbA.close();
    await dbB.close();

    final files = tempDir.listSync().map((f) => p.basename(f.path)).toList();
    expect(files.where((f) => f.endsWith('.db')).length, 2);
  });

  test('migrates version 1 without losing inspection data', () async {
    const projectUrl = 'https://legacy.supabase.co';
    final origin = Uri.parse(projectUrl).origin;
    final fileId = const Uuid().v5(Namespace.url.value, origin);
    final path = p.join(tempDir.path, 'inspections_$fileId.db');
    final oldDb = await ffiFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in _versionOneSchema) {
            await db.execute(sql);
          }
        },
      ),
    );
    await oldDb.insert('installation', {
      'id': 1,
      'project_url': origin,
      'device_id': 'legacy-device',
      'loaded_at': '2026-09-18T20:00:00.000Z',
    });
    await oldDb.insert('occurrence_types', {
      'id': 'type-1',
      'name': 'Praga',
      'code': 'pest',
    });
    await oldDb.insert('cached_plants', {
      'id': 'plant-1',
      'snapshot': '{"id":"plant-1","latitude":-23.1,"longitude":-46.1,"openTypeIds":[],"eligible":true}',
    });
    await oldDb.insert('local_inspections', {
      'local_id': 'draft-1',
      'started_at': '2026-09-18T20:00:00.000Z',
      'state': 'in_progress',
      'sync_status': 'pending',
    });
    await oldDb.insert('local_inspection_loaded_plants', {
      'inspection_local_id': 'draft-1',
      'plant_id': 'plant-1',
      'snapshot': '{"id":"plant-1","latitude":-23.1,"longitude":-46.1,"openTypeIds":[],"eligible":true}',
    });
    await oldDb.insert('local_inspection_changes', {
      'local_id': 'change-1',
      'inspection_local_id': 'draft-1',
      'plant_id': 'plant-1',
      'occurrence_type_id': 'type-1',
      'change_type': 'add_occurrence',
      'sequence': 1,
      'changed_at': '2026-09-18T20:01:00.000Z',
    });
    await oldDb.close();

    final migrated = InspectionDatabase(
      projectUrl: projectUrl,
      factory: ffiFactory,
      directory: tempDir.path,
    );
    final raw = await migrated.database;

    expect(await raw.getVersion(), 2);
    expect(await migrated.deviceId, 'legacy-device');
    expect(await raw.query('local_inspections'), hasLength(1));
    expect(await raw.query('local_inspection_changes'), hasLength(1));
    expect(await raw.query('cached_plants'), hasLength(1));
    expect(
      await raw.query(
        'cache_metadata',
        where: 'cache_key = ?',
        whereArgs: ['occurrence_types'],
      ),
      hasLength(1),
    );
    expect(
      await raw.query(
        'cache_metadata',
        where: 'cache_key = ?',
        whereArgs: ['plants'],
      ),
      isEmpty,
    );
    await migrated.close();
  });
}

const _versionOneSchema = <String>[
  '''CREATE TABLE installation (id INTEGER PRIMARY KEY CHECK(id = 1),
    project_url TEXT NOT NULL, device_id TEXT NOT NULL, loaded_at TEXT)''',
  '''CREATE TABLE occurrence_types (id TEXT PRIMARY KEY, name TEXT NOT NULL,
    code TEXT NOT NULL)''',
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
];
