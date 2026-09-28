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

class CountingLocalStore extends InspectionLocalStore {
  CountingLocalStore(super.database);
  int reads = 0;
  @override
  Future<List<Map<String, dynamic>>?> readSharedPlantRows() {
    reads++;
    return super.readSharedPlantRows();
  }
}

class CountingFarmRemoteDataSource implements FarmRemoteDataSource {
  List<Map<String, dynamic>> farmRows = const [];
  List<Map<String, dynamic>> plantRows = const [];
  List<List<Map<String, dynamic>>>? plantPages;
  Future<List<Map<String, dynamic>>> Function(int from, int to)?
  plantPageLoader;
  List<Map<String, dynamic>> zoneRows = const [];
  final Map<String, List<Map<String, dynamic>>> regionRows = {};

  int farmCalls = 0;
  int plantCalls = 0;
  int plantPageCalls = 0;
  int zoneCalls = 0;
  final Map<String, int> regionCalls = {};
  Completer<List<Map<String, dynamic>>>? farmCompleter;
  Duration remoteDelay = Duration.zero;
  int activeRemoteCalls = 0;
  int maxActiveRemoteCalls = 0;
  bool throwFarm = false;
  bool throwPlants = false;
  bool throwZones = false;

  Future<T> _trackRemote<T>(FutureOr<T> Function() load) async {
    activeRemoteCalls++;
    maxActiveRemoteCalls = maxActiveRemoteCalls < activeRemoteCalls
        ? activeRemoteCalls
        : maxActiveRemoteCalls;
    try {
      if (remoteDelay > Duration.zero) await Future<void>.delayed(remoteDelay);
      return await load();
    } finally {
      activeRemoteCalls--;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows() async {
    return _trackRemote(() async {
      farmCalls++;
      if (throwFarm) throw Exception('farm failed');
      return farmCompleter?.future ?? farmRows;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({
    int pageSize = 1000,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await fetchPlantRowsPage(
        from: from,
        to: from + pageSize - 1,
      );
      if (page.isEmpty) return rows;
      rows.addAll(page);
      from += page.length;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlantRowsPage({
    required int from,
    required int to,
  }) async {
    return _trackRemote(() async {
      plantPageCalls++;
      if (from == 0) plantCalls++;
      if (throwPlants) throw Exception('plants failed');
      final loader = plantPageLoader;
      if (loader != null) return loader(from, to);
      final pages = plantPages;
      if (pages != null) {
        final pageIndex = plantPageCalls - 1;
        if (pageIndex >= pages.length) return const [];
        return pages[pageIndex];
      }
      if (from >= plantRows.length) return const [];
      final end = (to + 1).clamp(0, plantRows.length);
      return plantRows.sublist(from, end);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchZonesRows() async {
    return _trackRemote(() {
      zoneCalls++;
      if (throwZones) throw Exception('zones failed');
      return zoneRows;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId) async {
    return _trackRemote(() {
      regionCalls[zoneId] = (regionCalls[zoneId] ?? 0) + 1;
      return regionRows[zoneId] ?? const [];
    });
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
  late CountingLocalStore localStore;
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
    localStore = CountingLocalStore(database);
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
    'hydrates once per committed revision including known empty cache',
    () async {
      await localStore.replaceSharedPlantRows(
        [],
        {},
        loadedAt: DateTime.utc(2026),
      );
      final initial = await Future.wait(
        List.generate(10, (_) => repository.getPlantRows()),
      );
      expect(initial.every((rows) => rows.isEmpty), isTrue);
      expect(localStore.reads, 1);
      expect(await repository.getPlantRows(), isEmpty);
      expect(localStore.reads, 1);
      expect(farmRemote.plantCalls, 0);

      final otherStore = InspectionLocalStore(database);
      await otherStore.replaceSharedPlantRows(
        [
          {'id': 'same-id', 'latitude': 1.0, 'longitude': 2.0},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      final first = await repository.getPlantRows();
      expect(first.single['latitude'], 1.0);
      await otherStore.replaceSharedPlantRows(
        [
          {'id': 'same-id', 'latitude': 3.0, 'longitude': 4.0},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      final second = await repository.getPlantRows();
      expect(second.single['latitude'], 3.0);
      expect(localStore.reads, 3);
      expect(identical(first, second), isFalse);
    },
  );

  test('committed occurrence edits invalidate warm plant hydration', () async {
    await localStore.replaceSharedPlantRows(
      [
        {'id': 'p'},
      ],
      {},
      loadedAt: DateTime.utc(2026),
    );
    await localStore.saveCatalog([
      const OccurrenceType(id: 't', name: 'Type', code: 'type'),
    ]);
    final first = await repository.getPlantRows();
    await localStore.toggle('p', 't');
    final second = await repository.getPlantRows();
    expect(InspectionPlant.fromJson(first.single).openTypeIds, isEmpty);
    expect(InspectionPlant.fromJson(second.single).openTypeIds, {'t'});
    expect(localStore.reads, 2);
  });

  test('independent projects never reuse another project snapshot', () async {
    final otherDb = InspectionDatabase(
      projectUrl: 'https://other-project.invalid',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    final otherStore = CountingLocalStore(otherDb);
    final other = SharedReadRepository(
      localStore: otherStore,
      farmRemoteDataSource: farmRemote,
      inspectionRemoteDataSource: inspectionRemote,
    );
    try {
      await localStore.replaceSharedPlantRows(
        [
          {'id': 'first'},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      await otherStore.replaceSharedPlantRows(
        [
          {'id': 'second'},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      expect((await repository.getPlantRows()).single['id'], 'first');
      expect((await other.getPlantRows()).single['id'], 'second');
      expect((await repository.getPlantRows()).single['id'], 'first');
      expect(localStore.reads, 1);
      expect(otherStore.reads, 1);
    } finally {
      await other.dispose();
      await otherDb.close();
    }
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

  test('limits concurrent remote reads to two operations', () async {
    farmRemote.remoteDelay = const Duration(milliseconds: 20);
    farmRemote.farmRows = const [
      {'id': 1, 'latitude': -23.0, 'longitude': -46.0, 'order': 1},
    ];
    farmRemote.zoneRows = const [
      {'id': 'zone-a', 'name': 'Zona A'},
    ];
    farmRemote.regionRows['zone-a'] = const [
      {'zone_id': 'zone-a', 'latitude': -23.1, 'longitude': -46.1},
    ];
    farmRemote.regionRows['zone-b'] = const [
      {'zone_id': 'zone-b', 'latitude': -23.2, 'longitude': -46.2},
    ];

    await Future.wait([
      repository.getFarmBoundaryRows(),
      repository.getZoneRows(),
      repository.getRegionRows('zone-a'),
      repository.getRegionRows('zone-b'),
    ]);

    expect(farmRemote.maxActiveRemoteCalls, lessThanOrEqualTo(2));
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

  test(
    'warm inventory totals do not hydrate the full plant snapshot',
    () async {
      await localStore.replaceSharedPlantRows(
        [
          {'id': 'p-1', 'non_existent': false},
          {'id': 'p-2', 'non_existent': true},
          {'id': 'p-3', 'non_existent': false},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      await localStore.replaceFarmRows(const []);
      await localStore.replaceZoneRows(const []);

      final summary = await SupabaseInventoryRepository.fromShared(repository)
          .fetchSummary();

      expect(summary.existingPlants, 2);
      expect(summary.availablePlantingSpots, 1);
      expect(localStore.reads, 0);
      expect(farmRemote.plantCalls, 0);
    },
  );

  test(
    'warm inventory summary reuses cached references without remote GETs',
    () async {
      await localStore.replaceSharedPlantRows(
        [
          {'id': 'p-1', 'non_existent': false},
          {'id': 'p-2', 'non_existent': true},
        ],
        {},
        loadedAt: DateTime.utc(2026),
      );
      await localStore.replaceFarmRows(const [
        {'id': 1, 'latitude': -23.0, 'longitude': -46.0, 'order': 1},
      ]);
      await localStore.replaceZoneRows(const [
        {'id': 'zone-a', 'name': 'Zona A'},
      ]);
      await localStore.replaceRegionRows('zone-a', const [
        {'zone_id': 'zone-a', 'latitude': -23.1, 'longitude': -46.1},
        {'zone_id': 'zone-a', 'latitude': -23.2, 'longitude': -46.2},
      ]);

      final inventory = SupabaseInventoryRepository.fromShared(repository);
      final first = await inventory.fetchSummary();
      final second = await inventory.fetchSummary();

      expect(first.existingPlants, 1);
      expect(first.availablePlantingSpots, 1);
      expect(first.zones, 1);
      expect(first.regionPoints, 2);
      expect(first.farmBoundaryPoints, 1);
      expect(second.regionPoints, 2);
      expect(localStore.reads, 0);
      expect(farmRemote.plantCalls, 0);
      expect(farmRemote.farmCalls, 0);
      expect(farmRemote.zoneCalls, 0);
      expect(farmRemote.regionCalls, isEmpty);
    },
  );

  test('upgraded cache computes missing plant totals once', () async {
    await localStore.replaceSharedPlantRows(
      [
        {'id': 'p-1', 'non_existent': false},
        {'id': 'p-2', 'non_existent': true},
      ],
      {},
      loadedAt: DateTime.utc(2026),
    );
    final db = await database.database;
    await db.update(
      'cache_metadata',
      {
        'row_count': null,
        'existing_plants': null,
        'available_planting_spots': null,
      },
      where: 'cache_key = ?',
      whereArgs: [InspectionLocalStore.plantsCacheKey],
    );

    final first = await repository.getPlantTotals();
    final second = await repository.getPlantTotals();

    expect(first.existingPlants, 1);
    expect(first.availablePlantingSpots, 1);
    expect(second.existingPlants, 1);
    expect(localStore.reads, 0);
  });

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

  test(
    'refresh persists plant pages through staging before publishing',
    () async {
      farmRemote.plantPages = const [
        [
          {
            'id': 'p-1',
            'latitude': -23.1,
            'longitude': -46.1,
            'non_existent': false,
          },
        ],
        [
          {
            'id': 'p-2',
            'latitude': null,
            'longitude': null,
            'non_existent': true,
          },
        ],
        [],
      ];

      final rows = await repository.refreshPlantRows();
      final totals = await repository.getPlantTotals();

      expect(rows.map((row) => row['id']), ['p-1', 'p-2']);
      expect(totals.existingPlants, 1);
      expect(totals.availablePlantingSpots, 1);
      expect(farmRemote.plantCalls, 1);
      expect(farmRemote.plantPageCalls, 3);
    },
  );

  test(
    'timeout during refresh discards staging and keeps previous revision',
    () async {
      farmRemote.plantRows = const [
        {
          'id': 'p-1',
          'latitude': -23.1,
          'longitude': -46.1,
          'non_existent': false,
        },
      ];
      await repository.getPlantRows();
      await repository.dispose();
      repository = SharedReadRepository(
        localStore: localStore,
        farmRemoteDataSource: farmRemote,
        inspectionRemoteDataSource: inspectionRemote,
        remoteRequestTimeout: const Duration(milliseconds: 1),
      );

      farmRemote.plantPageLoader = (from, to) {
        if (from == 0) {
          return Future.value(const [
            {
              'id': 'partial',
              'latitude': -23.2,
              'longitude': -46.2,
              'non_existent': false,
            },
          ]);
        }
        return Completer<List<Map<String, dynamic>>>().future;
      };

      await expectLater(
        repository.refreshPlantRows(),
        throwsA(isA<TimeoutException>()),
      );

      final cached = await repository.getPlantRows();
      expect(cached.map((row) => row['id']), ['p-1']);
      final raw = await database.database;
      expect(await raw.query('staged_plants'), isEmpty);
      expect(
        await raw.query('cache_generations', where: 'is_complete = 0'),
        isEmpty,
      );
    },
  );

  test(
    'publishing staged refresh preserves a local edit made during refresh',
    () async {
      await localStore.saveCatalog([
        const OccurrenceType(id: 'type-1', name: 'Praga', code: 'pest'),
      ]);
      farmRemote.plantRows = const [
        {
          'id': 'p-1',
          'latitude': -23.1,
          'longitude': -46.1,
          'non_existent': false,
        },
      ];
      await repository.getPlantRows();

      var editedDuringRefresh = false;
      farmRemote.plantPageLoader = (from, to) async {
        if (from == 0) {
          return const [
            {
              'id': 'p-1',
              'latitude': -23.9,
              'longitude': -46.9,
              'non_existent': false,
            },
          ];
        }
        if (!editedDuringRefresh) {
          editedDuringRefresh = true;
          await localStore.toggle('p-1', 'type-1');
        }
        return const [];
      };

      final refreshed = await repository.refreshPlantRows();
      final plant = InspectionPlant.fromJson(refreshed.single);

      expect(plant.latitude, -23.9);
      expect(plant.openTypeIds, {'type-1'});
    },
  );

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
    localStore = CountingLocalStore(database);
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
