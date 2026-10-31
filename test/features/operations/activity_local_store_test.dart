import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomar_na_mao_mobile/features/operations/data/activity_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late ActivityDatabase database;
  late ActivityLocalStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('activity_test_');
    database = ActivityDatabase(
      projectUrl: 'https://project.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    var sequence = 0;
    store = ActivityLocalStore(
      database,
      newId: () => 'generated-${sequence++}',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'creates schema with foreign keys and stable project installation',
    () async {
      final db = await database.database;
      final pragma = await db.rawQuery('PRAGMA foreign_keys');
      final installation = await db.query('installation');

      expect(pragma.single.values.single, 1);
      expect(installation.single['project_url'], 'https://project.supabase.co');
      expect(await database.deviceId, isNotEmpty);
    },
  );

  test('renames the legacy database and preserves pending entries', () async {
    final fileId = const Uuid().v5(
      Namespace.url.value,
      'https://project.supabase.co',
    );
    final legacyPath = p.join(directory.path, 'field_notebook_$fileId.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE installation (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            project_url TEXT NOT NULL,
            device_id TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE local_field_notebook_entries (
            local_id TEXT PRIMARY KEY,
            geometry_type TEXT NOT NULL,
            geometry_geojson TEXT NOT NULL,
            activity TEXT NOT NULL,
            performed_at TEXT NOT NULL,
            responsible TEXT NOT NULL,
            payload_fingerprint TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            error TEXT,
            remote_field_operation_id TEXT,
            remote_entry_id TEXT,
            synced_at TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
          await db.execute('''CREATE TABLE local_field_notebook_entry_inputs (
            local_id TEXT PRIMARY KEY,
            entry_local_id TEXT NOT NULL REFERENCES local_field_notebook_entries(local_id) ON DELETE CASCADE,
            input_id TEXT NOT NULL,
            name_snapshot TEXT NOT NULL,
            active_ingredient_snapshot TEXT,
            label_dose_snapshot TEXT,
            dose_unit_snapshot TEXT,
            applied_dose TEXT NOT NULL,
            UNIQUE(entry_local_id, input_id))''');
          await db.execute('''CREATE INDEX local_field_notebook_queue
            ON local_field_notebook_entries(sync_status, performed_at)''');
          await db.execute('''CREATE INDEX local_field_notebook_inputs_entry
            ON local_field_notebook_entry_inputs(entry_local_id)''');
        },
      ),
    );
    await legacy.insert('installation', {
      'id': 1,
      'project_url': 'https://project.supabase.co',
      'device_id': 'legacy-device',
    });
    await legacy.insert('local_field_notebook_entries', {
      'local_id': 'legacy-entry',
      'geometry_type': 'route',
      'geometry_geojson':
          '{"type":"LineString","coordinates":[[-47,-21],[-47.1,-21.1]]}',
      'activity': 'roçagem',
      'performed_at': DateTime.utc(2026, 10, 30).toIso8601String(),
      'responsible': 'João',
      'payload_fingerprint': 'legacy',
      'sync_status': 'pending',
    });
    await legacy.close();

    final upgraded = await database.database;

    expect(await database.deviceId, 'legacy-device');
    expect(
      (await upgraded.query('local_activity_entries')).single['local_id'],
      'legacy-entry',
    );
    expect(
      await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'local_field_notebook%'",
      ),
      isEmpty,
    );
    expect(await File(legacyPath).exists(), isFalse);
  });

  test('saves entry and input atomically and reconciles sync status', () async {
    final created = await store.create(
      localId: 'entry-1',
      geometry: _route,
      activity: ' roçagem ',
      performedAt: DateTime.utc(2026, 10, 30, 15, 30),
      responsible: 'João',
      inputs: const [
        ActivityInput(
          localId: 'input-local-1',
          inputId: 'input-1',
          nameSnapshot: 'Produto',
          activeIngredientSnapshot: 'Ingrediente',
          labelDoseSnapshot: '50 - 100',
          doseUnitSnapshot: 'mL/100L',
          appliedDose: '75 mL/100L',
        ),
      ],
    );
    expect(created.activity, 'roçagem');
    expect((await store.list()).single.inputs.single.appliedDose, '75 mL/100L');

    await store.markSyncing(['entry-1']);
    expect(
      (await store.find('entry-1'))!.syncStatus,
      ActivitySyncStatus.syncing,
    );
    await store.markSynced(
      ActivitySyncResult(
        localId: 'entry-1',
        fieldOperationId: 'remote-operation',
        entryId: 'remote-entry',
        inputsCount: 1,
        syncedAt: DateTime.utc(2026, 10, 30, 16),
      ),
    );
    final synced = (await store.list()).single;
    expect(synced.syncStatus, ActivitySyncStatus.synced);
    expect(synced.remoteEntryId, 'remote-entry');
  });

  test('saves selected mixture and snapshots its composition', () async {
    final created = await store.create(
      localId: 'entry-mixture',
      geometry: _route,
      activity: 'aplicação',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      mixture: MixtureCatalogItem(
        id: 'mixture-1',
        name: 'Calda cítrica',
        isActive: true,
        inputs: const [
          MixtureInputCatalogItem(
            inputId: 'input-1',
            name: 'Produto',
            dose: '75',
            doseUnit: 'mL/100L',
          ),
        ],
      ),
    );

    expect(created.mixtureId, 'mixture-1');
    expect(created.mixtureNameSnapshot, 'Calda cítrica');
    expect(created.inputs.single.appliedDose, '75');
    final reopened = await store.find('entry-mixture');
    expect(reopened!.mixtureNameSnapshot, 'Calda cítrica');
    expect(reopened.inputs.single.nameSnapshot, 'Produto');
  });

  test('saves the optional machine reference and snapshots', () async {
    final created = await store.create(
      localId: 'entry-machine',
      geometry: _route,
      activity: 'roçagem',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      machine: MachineCatalogItem(
        id: 'machine-1',
        name: 'Trator Valtra A950',
        brand: 'Valtra',
      ),
    );

    expect(created.machineId, 'machine-1');
    expect(created.machineNameSnapshot, 'Trator Valtra A950');
    expect(created.machineBrandSnapshot, 'Valtra');
    final reopened = await store.find('entry-machine');
    expect(reopened!.machineId, 'machine-1');
    expect(reopened.machineNameSnapshot, 'Trator Valtra A950');
    expect(reopened.machineBrandSnapshot, 'Valtra');
  });

  test('rolls back entry when an input violates local uniqueness', () async {
    const firstInput = ActivityInput(
      localId: 'input-local',
      inputId: 'input-1',
      nameSnapshot: 'Produto',
      appliedDose: '1 L/ha',
    );
    await store.create(
      localId: 'entry-base',
      geometry: _route,
      activity: 'aplicação',
      performedAt: DateTime.utc(2026, 10, 29),
      responsible: 'João',
      inputs: const [firstInput],
    );
    await expectLater(
      store.create(
        localId: 'entry-rollback',
        geometry: _route,
        activity: 'aplicação',
        performedAt: DateTime.utc(2026, 10, 30),
        responsible: 'João',
        inputs: const [
          ActivityInput(
            localId: 'input-local',
            inputId: 'input-2',
            nameSnapshot: 'Outro produto',
            appliedDose: '2 L/ha',
          ),
        ],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.find('entry-rollback'), isNull);
    expect(await store.list(), hasLength(1));
  });

  test('deletes local entry and cascades its input snapshots', () async {
    await store.create(
      localId: 'entry-delete',
      geometry: _route,
      activity: 'adubação',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      inputs: const [
        ActivityInput(
          localId: 'input-delete',
          inputId: 'input-1',
          nameSnapshot: 'Produto',
          appliedDose: '1 L/ha',
        ),
      ],
    );

    expect(await store.delete('entry-delete'), isTrue);
    expect(await store.find('entry-delete'), isNull);
    final db = await database.database;
    expect(
      await db.query(
        'local_activity_entry_inputs',
        where: 'entry_local_id = ?',
        whereArgs: ['entry-delete'],
      ),
      isEmpty,
    );
    expect(await store.delete('entry-delete'), isFalse);
  });

  test('recovers syncing rows as pending after reopen', () async {
    await store.create(
      localId: 'entry-restart',
      geometry: _route,
      activity: 'roçagem',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      inputs: const [],
    );
    await store.markSyncing(['entry-restart']);
    await database.close();

    database = ActivityDatabase(
      projectUrl: 'https://project.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    store = ActivityLocalStore(database);
    expect(
      (await store.find('entry-restart'))!.syncStatus,
      ActivitySyncStatus.pending,
    );
  });
}

final _route = ActivityGeometry(
  type: ActivityGeometryType.route,
  points: const [ActivityPoint(-21, -47), ActivityPoint(-21.1, -47.1)],
);
