import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/harvest_forecast_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeHarvestForecastRemoteDataSource
    implements HarvestForecastRemoteDataSource {
  Map<String, dynamic>? lastPayload;
  List<HarvestForecastSyncResult> nextResults = const [];
  Object? nextError;

  @override
  Future<List<HarvestForecastSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async {
    lastPayload = payload;
    if (nextError != null) throw nextError!;
    return nextResults;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late HarvestForecastDatabase forecastDb;
  late InspectionDatabase inspectionDb;
  late HarvestForecastLocalStore localStore;
  late InspectionLocalStore inspectionLocalStore;
  late _FakeHarvestForecastRemoteDataSource remoteDataSource;
  late DefaultHarvestForecastRepository repository;
  var idCounter = 0;

  setUp(() async {
    idCounter = 0;
    tempDir = await Directory.systemTemp.createTemp(
      'harvest_forecast_repo_test_',
    );
    forecastDb = HarvestForecastDatabase(
      projectUrl: 'https://harvest-forecast-repo-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    inspectionDb = InspectionDatabase(
      projectUrl: 'https://harvest-forecast-repo-test.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    localStore = HarvestForecastLocalStore(
      forecastDb,
      newId: () => 'local-${++idCounter}',
      clock: () => DateTime.utc(2026, 11, 19, 10, 0, idCounter),
    );
    inspectionLocalStore = InspectionLocalStore(inspectionDb);
    remoteDataSource = _FakeHarvestForecastRemoteDataSource();
    repository = DefaultHarvestForecastRepository(
      localStore: localStore,
      remoteDataSource: remoteDataSource,
      inspectionLocalStore: inspectionLocalStore,
      refreshSharedCache: () async {
        await inspectionLocalStore.replaceSnapshot(
          InspectionSnapshot(
            plants: [
              InspectionPlant(
                id: 'plant-1',
                latitude: -23.1,
                longitude: -46.1,
                zoneId: 'zone-1',
              ),
            ],
            types: const [],
            loadedAt: DateTime.utc(2026, 11, 19),
          ),
        );
      },
    );
  });

  tearDown(() async {
    await forecastDb.close();
    await inspectionDb.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('loads plants and saves, updates, deletes and syncs markings', () async {
    final plants = await repository.loadPlants(forceRemote: true);
    expect(plants, hasLength(1));
    expect(plants.single.id, 'plant-1');

    final m1 = await repository.save(
      latitude: -23.1,
      longitude: -46.1,
      classification: HarvestForecastClassification.p,
    );
    final m2 = await repository.save(
      latitude: -23.2,
      longitude: -46.2,
      classification: HarvestForecastClassification.g,
    );

    remoteDataSource.nextResults = [
      HarvestForecastSyncResult(
        localMarkingId: m1.localId,
        id: 'remote-1',
        plantId: 'plant-1',
        zoneId: 'zone-1',
        syncedAt: DateTime.utc(2026, 11, 19, 12),
      ),
    ];

    expect(await repository.syncOne(m1.localId), isTrue);
    final afterOne = await repository.list();
    expect(
      afterOne.firstWhere((m) => m.localId == m1.localId).status,
      HarvestForecastSyncStatus.synced,
    );
    expect(
      afterOne.firstWhere((m) => m.localId == m2.localId).status,
      HarvestForecastSyncStatus.pending,
    );

    await repository.updateClassification(
      localId: m2.localId,
      classification: HarvestForecastClassification.gg,
    );

    remoteDataSource.nextResults = [
      HarvestForecastSyncResult(
        localMarkingId: m2.localId,
        id: 'remote-2',
        plantId: 'plant-2',
        zoneId: 'zone-1',
        syncedAt: DateTime.utc(2026, 11, 19, 12, 5),
      ),
    ];

    expect(await repository.syncAll(), isTrue);
    final afterAll = await repository.list();
    expect(
      afterAll.every((m) => m.status == HarvestForecastSyncStatus.synced),
      isTrue,
    );

    expect(await repository.delete(m1.localId), isTrue);
    expect((await repository.list()).map((m) => m.localId), [m2.localId]);
  });

  test('marks error on sync failure and allows retry', () async {
    final m1 = await repository.save(
      latitude: -23.1,
      longitude: -46.1,
      classification: HarvestForecastClassification.m,
    );
    remoteDataSource.nextError = Exception('Falha de rede');

    expect(await repository.syncOne(m1.localId), isFalse);
    final failed = (await repository.list()).single;
    expect(failed.status, HarvestForecastSyncStatus.error);
    expect(failed.error, contains('Falha de rede'));
  });
}
