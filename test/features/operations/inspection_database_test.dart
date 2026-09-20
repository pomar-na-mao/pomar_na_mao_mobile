import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('creates tables, indices, and persists deviceId across reopens', () async {
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
    expect(tableNames, containsAll({
      'installation',
      'occurrence_types',
      'cached_plants',
      'local_inspections',
      'local_inspection_loaded_plants',
      'local_inspection_changes',
    }));

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
  });

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
}
