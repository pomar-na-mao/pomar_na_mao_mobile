import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/data/shared_read_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/datasources/farm_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/inventory/data/supabase_inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CountingFarmRemoteDataSource implements FarmRemoteDataSource {
  List<Map<String, dynamic>> farmRows = const [];
  List<Map<String, dynamic>> plantRows = const [];
  List<Map<String, dynamic>> zoneRows = const [];
  final Map<String, List<Map<String, dynamic>>> regionRows = {};

  int farmCalls = 0;
  int plantCalls = 0;
  int zoneCalls = 0;
  final Map<String, int> regionCalls = {};
  Completer<List<Map<String, dynamic>>>? farmCompleter;
  bool throwFarm = false;
  bool throwPlants = false;
  bool throwZones = false;

  @override
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows() async {
    farmCalls++;
    if (throwFarm) throw Exception('farm failed');
    return farmCompleter?.future ?? farmRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({
    int pageSize = 1000,
  }) async {
    plantCalls++;
    if (throwPlants) throw Exception('plants failed');
    return plantRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchZonesRows() async {
    zoneCalls++;
    if (throwZones) throw Exception('zones failed');
    return zoneRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId) async {
    regionCalls[zoneId] = (regionCalls[zoneId] ?? 0) + 1;
    return regionRows[zoneId] ?? const [];
  }
}

class CountingInspectionRemoteDataSource implements InspectionRemoteDataSource {
  List<OccurrenceType> types = const [];
  Map<String, Set<String>> openOccurrences = const {};
  int catalogCalls = 0;
  int openOccurrenceCalls = 0;
  bool throwOpenOccurrences = false;

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async {
    catalogCalls++;
    return types;
  }

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async =>
      const [];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async {
    openOccurrenceCalls++;
    if (throwOpenOccurrences) throw Exception('occurrences failed');
    return {
      for (final entry in openOccurrences.entries)
        if (plantIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async =>
      InspectionSnapshot(
        plants: const [],
        types: types,
        loadedAt: DateTime.now(),
      );

  @override
  Future<InspectionSyncResult> syncInspection(
    Map<String, dynamic> payload,
  ) async => const InspectionSyncResult(
    operationId: 'operation',
    created: 0,
    updated: 0,
    resolved: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late InspectionDatabase database;
  late InspectionLocalStore localStore;
  late CountingFarmRemoteDataSource farmRemote;
  late CountingInspectionRemoteDataSource inspectionRemote;
  late SharedReadRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shared_read_cache_test_');
    database = InspectionDatabase(
      projectUrl: 'https://shared-cache.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    localStore = InspectionLocalStore(database);
    farmRemote = CountingFarmRemoteDataSource();
    inspectionRemote = CountingInspectionRemoteDataSource();
    repository = SharedReadRepository(
      localStore: localStore,
      farmRemoteDataSource: farmRemote,
      inspectionRemoteDataSource: inspectionRemote,
      clock: () => DateTime.utc(2026, 9, 20, 12),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await database.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'deduplicates concurrent reference loads and persists an empty result',
    () async {
      final completer = Completer<List<Map<String, dynamic>>>();
      farmRemote.farmCompleter = completer;

      final first = repository.getFarmBoundaryRows();
      while (farmRemote.farmCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = repository.getFarmBoundaryRows();

      expect(farmRemote.farmCalls, 1);
      completer.complete(const []);
      expect(await first, isEmpty);
      expect(await second, isEmpty);
      expect(await repository.getFarmBoundaryRows(), isEmpty);
      expect(farmRemote.farmCalls, 1);
    },
  );

  test('allows retry after a shared reference load fails', () async {
    farmRemote.throwZones = true;
    await expectLater(repository.getZoneRows(), throwsException);

    farmRemote.throwZones = false;
    farmRemote.zoneRows = const [
      {'id': 'zone-a', 'name': 'Zona A', 'code': 'A'},
    ];
    final zones = await repository.getZoneRows();

    expect(zones.single['id'], 'zone-a');
    expect(farmRemote.zoneCalls, 2);
  });

  test(
    'bootstraps plants once, derives totals, and refreshes explicitly',
    () async {
      farmRemote.plantRows = const [
        {
          'id': 'p-1',
          'latitude': -23.1,
          'longitude': -46.1,
          'description': 'Planta 1',
          'zone_id': 'zone-a',
          'non_existent': false,
        },
        {
          'id': 'p-2',
          'latitude': null,
          'longitude': null,
          'description': 'Posição livre',
          'zone_id': 'zone-a',
          'non_existent': true,
        },
      ];
      inspectionRemote.openOccurrences = {
        'p-1': {'type-1'},
      };
      var revisions = 0;
      final subscription = repository.plantChanges.listen((_) => revisions++);

      final first = repository.getPlantRows();
      final second = repository.getPlantRows();
      final results = await Future.wait([first, second]);

      expect(results.first, hasLength(2));
      expect(results.last, hasLength(2));
      expect(farmRemote.plantCalls, 1);
      expect(inspectionRemote.openOccurrenceCalls, 1);
      expect(revisions, 1);

      final summary = await SupabaseInventoryRepository.fromShared(repository)
          .fetchSummary();
      expect(summary.existingPlants, 1);
      expect(summary.availablePlantingSpots, 1);
      expect(farmRemote.plantCalls, 1);

      farmRemote.plantRows = const [
        {
          'id': 'p-3',
          'latitude': -23.3,
          'longitude': -46.3,
          'description': 'Planta 3',
          'zone_id': 'zone-b',
          'non_existent': false,
        },
      ];
      final refreshed = await repository.refreshPlantRows();
      expect(refreshed.map((row) => row['id']), ['p-3']);
      expect(farmRemote.plantCalls, 2);
      expect(revisions, 2);

      await subscription.cancel();
      await repository.refreshPlantRows();
      expect(revisions, 2);
    },
  );

  test('keeps the previous plant revision when refresh fails', () async {
    farmRemote.plantRows = const [
      {
        'id': 'p-1',
        'latitude': -23.1,
        'longitude': -46.1,
        'non_existent': false,
      },
    ];
    await repository.getPlantRows();
    var revisions = 0;
    final subscription = repository.plantChanges.listen((_) => revisions++);

    farmRemote.plantRows = const [
      {
        'id': 'partial',
        'latitude': -20.0,
        'longitude': -40.0,
        'non_existent': false,
      },
    ];
    inspectionRemote.throwOpenOccurrences = true;
    await expectLater(repository.refreshPlantRows(), throwsException);

    final cached = await repository.getPlantRows();
    expect(cached.map((row) => row['id']), ['p-1']);
    expect(revisions, 0);
    await subscription.cancel();
  });

  test('preserves pending changes for a plant removed remotely', () async {
    inspectionRemote.types = const [
      OccurrenceType(id: 'type-1', name: 'Praga', code: 'pest'),
    ];
    await repository.getOccurrenceTypes();
    farmRemote.plantRows = const [
      {
        'id': 'p-1',
        'latitude': -23.1,
        'longitude': -46.1,
        'non_existent': false,
      },
    ];
    await repository.getPlantRows();
    await localStore.toggle('p-1', 'type-1');

    farmRemote.plantRows = const [
      {
        'id': 'p-2',
        'latitude': -23.2,
        'longitude': -46.2,
        'non_existent': false,
      },
    ];
    await repository.refreshPlantRows();

    final cached = await repository.getPlantRows();
    final retained = cached.firstWhere((row) => row['id'] == 'p-1');
    expect(retained['eligible'], isFalse);
    expect(retained['openTypeIds'], contains('type-1'));
  });

  test(
    'inspection refresh filters unavailable plants and reuses catalog',
    () async {
      inspectionRemote.types = const [
        OccurrenceType(id: 'type-1', name: 'Praga', code: 'pest'),
      ];
      farmRemote.plantRows = const [
        {
          'id': 'p-1',
          'latitude': -23.1,
          'longitude': -46.1,
          'non_existent': false,
        },
        {
          'id': 'p-2',
          'latitude': -23.2,
          'longitude': -46.2,
          'non_existent': true,
        },
      ];
      final inspectionRepository = DefaultInspectionRepository(
        localStore: localStore,
        remoteDataSource: inspectionRemote,
        sharedReadRepository: repository,
      );

      expect(await inspectionRepository.loadSnapshot(), isNull);
      final refreshed = await inspectionRepository.loadSnapshot(
        forceRemote: true,
      );
      expect(refreshed!.plants.map((plant) => plant.id), ['p-1']);
      expect(refreshed.types, hasLength(1));
      expect(inspectionRemote.catalogCalls, 1);
      expect(farmRemote.plantCalls, 1);

      expect((await inspectionRepository.loadSnapshot())!.plants, hasLength(1));
      expect(await inspectionRepository.getCatalog(), hasLength(1));
      expect(inspectionRemote.catalogCalls, 1);
      expect(farmRemote.plantCalls, 1);
    },
  );

  test('reference replacement rolls back when a row is invalid', () async {
    await localStore.replaceZoneRows(const [
      {'id': 'zone-a', 'name': 'Zona A'},
    ]);

    await expectLater(
      localStore.replaceZoneRows(const [
        {'name': 'Sem identificador'},
      ]),
      throwsFormatException,
    );

    final cached = await localStore.readZoneRows();
    expect(cached!.single['id'], 'zone-a');
  });

  test('shares data across consumers and a repository restart', () async {
    farmRemote.farmRows = const [
      {'id': 1, 'latitude': -23.0, 'longitude': -46.0, 'order': 1},
    ];
    farmRemote.plantRows = const [
      {
        'id': 'p-1',
        'latitude': -23.1,
        'longitude': -46.1,
        'non_existent': false,
      },
      {
        'id': 'p-2',
        'latitude': -23.2,
        'longitude': -46.2,
        'non_existent': true,
      },
    ];

    final inventory = SupabaseInventoryRepository.fromShared(repository);
    final firstSummary = await inventory.fetchSummary();
    expect(firstSummary.existingPlants, 1);
    expect(await repository.getPlantRows(), hasLength(2));
    expect(await repository.getFarmBoundaryRows(), hasLength(1));
    expect(farmRemote.plantCalls, 1);
    expect(farmRemote.farmCalls, 1);

    await repository.dispose();
    await database.close();
    database = InspectionDatabase(
      projectUrl: 'https://shared-cache.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    localStore = InspectionLocalStore(database);
    repository = SharedReadRepository(
      localStore: localStore,
      farmRemoteDataSource: farmRemote,
      inspectionRemoteDataSource: inspectionRemote,
    );

    expect(await repository.getPlantRows(), hasLength(2));
    expect(await repository.getFarmBoundaryRows(), hasLength(1));
    expect(farmRemote.plantCalls, 1);
    expect(farmRemote.farmCalls, 1);

    await repository.refreshPlantRows();
    expect(farmRemote.plantCalls, 2);
    expect(inspectionRemote.openOccurrenceCalls, 2);
  });
}
