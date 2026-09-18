import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';
import 'package:pomar_na_mao_mobile/features/inventory/presentation/inventory_view_model.dart';

class FakeInventoryRepository implements InventoryRepository {
  InventorySummary result = const InventorySummary(
    existingPlants: 100,
    availablePlantingSpots: 4,
  );
  Exception? error;
  Completer<InventorySummary>? completer;
  int calls = 0;

  @override
  Future<InventorySummary> fetchSummary() async {
    calls += 1;
    if (error case final error?) throw error;
    return completer?.future ?? result;
  }
}

class FakeFarmRepository implements FarmRepository {
  List<FarmPoint> result = const [
    FarmPoint(id: '1', latitude: -22.1, longitude: -48.9, boundaryOrder: 1),
    FarmPoint(id: '2', latitude: -22.2, longitude: -48.9, boundaryOrder: 2),
    FarmPoint(id: '3', latitude: -22.1, longitude: -48.8, boundaryOrder: 3),
  ];
  Exception? error;
  int calls = 0;

  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async {
    calls += 1;
    if (error case final error?) throw error;
    return result;
  }
}

class FakeZonesRepository implements ZonesRepository {
  List<Zone> zones = const [Zone(id: 'zone-a', name: 'Primeira', code: 'A')];
  Map<String, List<RegionPoint>> regionsByZone = {
    'zone-a': const [
      RegionPoint(latitude: -22.12, longitude: -48.88, zoneId: 'zone-a'),
      RegionPoint(latitude: -22.16, longitude: -48.90, zoneId: 'zone-a'),
      RegionPoint(latitude: -22.14, longitude: -48.84, zoneId: 'zone-a'),
    ],
  };
  Exception? zonesError;
  Exception? regionsError;
  int zoneCalls = 0;

  @override
  Future<List<Zone>> fetchZones() async {
    zoneCalls += 1;
    if (zonesError case final error?) throw error;
    return zones;
  }

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async {
    if (regionsError case final error?) throw error;
    return regionsByZone[zoneId] ?? const [];
  }
}

void main() {
  late FakeInventoryRepository inventoryRepository;
  late FakeFarmRepository farmRepository;
  late FakeZonesRepository zonesRepository;
  late InventoryViewModel viewModel;

  setUp(() {
    inventoryRepository = FakeInventoryRepository();
    farmRepository = FakeFarmRepository();
    zonesRepository = FakeZonesRepository();
    viewModel = InventoryViewModel(
      inventoryRepository,
      farmRepository,
      zonesRepository,
    );
  });

  tearDown(() => viewModel.dispose());

  test('loads summary and both polygons in parallel initialization', () async {
    await viewModel.initialize();

    expect(viewModel.summaryStatus, InventoryLoadStatus.success);
    expect(viewModel.summary?.existingPlants, 100);
    expect(viewModel.mapStatus, InventoryLoadStatus.success);
    expect(viewModel.farmBoundaryPoints, hasLength(3));
    expect(viewModel.zonePointsById['zone-a'], hasLength(3));
    expect(viewModel.mapMessage, isNull);
  });

  test('treats zero totals as successful data', () async {
    inventoryRepository.result = const InventorySummary(
      existingPlants: 0,
      availablePlantingSpots: 0,
    );

    await viewModel.loadSummary();

    expect(viewModel.summaryStatus, InventoryLoadStatus.success);
    expect(viewModel.summary?.existingPlants, 0);
  });

  test('keeps map successful when the totals fail', () async {
    inventoryRepository.error = Exception('summary failed');

    await viewModel.initialize();

    expect(viewModel.summaryStatus, InventoryLoadStatus.error);
    expect(viewModel.mapStatus, InventoryLoadStatus.success);
    expect(viewModel.farmBoundaryPoints, isNotEmpty);
  });

  test('keeps the available polygon and reports a partial failure', () async {
    farmRepository.error = Exception('farm failed');

    await viewModel.loadMapData();

    expect(viewModel.mapStatus, InventoryLoadStatus.success);
    expect(viewModel.farmBoundaryPoints, isEmpty);
    expect(viewModel.zonePointsById['zone-a'], hasLength(3));
    expect(viewModel.mapMessage, 'O limite da fazenda não pôde ser exibido.');
  });

  test('loads the region points for every zone from A to G', () async {
    zonesRepository.zones = List.generate(7, (index) {
      final code = String.fromCharCode('A'.codeUnitAt(0) + index);
      return Zone(
        id: 'zone-${code.toLowerCase()}',
        name: 'Zona $code',
        code: code,
      );
    });
    zonesRepository.regionsByZone = {
      for (final zone in zonesRepository.zones)
        zone.id: List.generate(
          3,
          (index) => RegionPoint(
            latitude: -22 - index / 100,
            longitude: -48 - index / 100,
            zoneId: zone.id,
          ),
        ),
    };

    await viewModel.loadMapData();

    expect(viewModel.zonePointsById.keys, hasLength(7));
    expect(viewModel.zonePointsById.values, everyElement(hasLength(3)));
    expect(viewModel.mapStatus, InventoryLoadStatus.success);
  });

  test('reports missing zones while retaining the farm polygon', () async {
    zonesRepository.zones = const [];

    await viewModel.loadMapData();

    expect(viewModel.farmBoundaryPoints, hasLength(3));
    expect(viewModel.zonePointsById, isEmpty);
    expect(viewModel.mapMessage, 'As zonas não puderam ser exibidas.');
  });

  test('reports an error when both geographic sources fail', () async {
    farmRepository.error = Exception('farm failed');
    zonesRepository.zonesError = Exception('zones failed');

    await viewModel.loadMapData();

    expect(viewModel.mapStatus, InventoryLoadStatus.error);
    expect(
      viewModel.mapMessage,
      'Não foi possível carregar os limites da propriedade.',
    );
  });

  test('retries summary without reloading geography', () async {
    inventoryRepository.error = Exception('first failure');
    await viewModel.loadSummary();
    inventoryRepository.error = null;

    await viewModel.loadSummary();

    expect(inventoryRepository.calls, 2);
    expect(farmRepository.calls, 0);
    expect(viewModel.summaryStatus, InventoryLoadStatus.success);
  });

  test('retries geography without reloading summary', () async {
    farmRepository.error = Exception('first failure');
    zonesRepository.zonesError = Exception('first failure');
    await viewModel.loadMapData();
    farmRepository.error = null;
    zonesRepository.zonesError = null;

    await viewModel.loadMapData();

    expect(farmRepository.calls, 2);
    expect(zonesRepository.zoneCalls, 2);
    expect(inventoryRepository.calls, 0);
    expect(viewModel.mapStatus, InventoryLoadStatus.success);
  });

  test(
    'does not notify after disposal when an async response arrives',
    () async {
      final completer = Completer<InventorySummary>();
      inventoryRepository.completer = completer;
      var notifications = 0;
      viewModel.addListener(() => notifications += 1);

      final loading = viewModel.loadSummary();
      expect(notifications, 1);
      viewModel.dispose();
      completer.complete(
        const InventorySummary(existingPlants: 1, availablePlantingSpots: 2),
      );
      await loading;

      expect(notifications, 1);
      viewModel = InventoryViewModel(
        inventoryRepository,
        farmRepository,
        zonesRepository,
      );
    },
  );
}
