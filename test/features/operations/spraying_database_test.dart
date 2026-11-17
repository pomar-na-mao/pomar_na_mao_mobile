import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();

  test(
    'version 2 upgrade removes confirmed plants and keeps GPS points',
    () async {
      final directory = await Directory.systemTemp.createTemp('spraying-db-');
      addTearDown(() => directory.delete(recursive: true));
      const projectUrl = 'https://spraying-upgrade.example';
      final project = Uri.parse(projectUrl).origin;
      final fileId = const Uuid().v5(Namespace.url.value, project);
      final path = p.join(directory.path, 'spraying_$fileId.db');

      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE installation (id INTEGER PRIMARY KEY, project_url TEXT NOT NULL, device_id TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE local_spraying_operations (local_id TEXT PRIMARY KEY, sync_status TEXT)',
            );
            await db.execute(
              'CREATE TABLE local_spraying_track_points (local_id TEXT PRIMARY KEY, operation_local_id TEXT)',
            );
            await db.execute(
              'CREATE TABLE local_spraying_confirmed_plants (local_id TEXT PRIMARY KEY, operation_local_id TEXT)',
            );
            await db.insert('installation', {
              'id': 1,
              'project_url': project,
              'device_id': 'device-1',
            });
            await db.insert('local_spraying_track_points', {
              'local_id': 'point-1',
              'operation_local_id': 'operation-1',
            });
          },
        ),
      );
      await legacy.close();

      final sprayingDatabase = SprayingDatabase(
        projectUrl: projectUrl,
        factory: databaseFactoryFfi,
        directory: directory.path,
      );
      addTearDown(sprayingDatabase.close);
      final upgraded = await sprayingDatabase.database;

      final confirmed = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'local_spraying_confirmed_plants'",
      );
      expect(confirmed, isEmpty);
      expect(await upgraded.query('local_spraying_track_points'), hasLength(1));
    },
  );
}
