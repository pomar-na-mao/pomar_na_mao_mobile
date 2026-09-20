import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view_model.dart';

class FakeLocationService implements LocationService {
  final _controller = StreamController<LocationResult>.broadcast();
  int watchCallCount = 0;

  LocationResult current = const LocationResult.serviceDisabled();

  @override
  Future<LocationResult> getCurrentLocation() async => current;

  @override
  Stream<LocationResult> watchLocation() {
    watchCallCount++;
    return _controller.stream;
  }

  void emit(LocationResult result) {
    current = result;
    _controller.add(result);
  }

  void dispose() {
    _controller.close();
  }
}

class FakeInspectionRepo implements InspectionRepository {
  InspectionSnapshot? currentSnapshot;
  List<LocalInspection> localList = [];
  bool syncSucceeds = true;

  int toggleCallCount = 0;
  int finalizeCallCount = 0;

  @override
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false}) async => currentSnapshot;

  @override
  Future<List<OccurrenceType>> getCatalog() async => currentSnapshot?.types ?? [];

  @override
  Future<void> togglePlantOccurrence(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  }) async {
    toggleCallCount++;
    if (currentSnapshot != null) {
      final plants = currentSnapshot!.plants.map((p) {
        if (p.id == plantId) {
          final types = {...p.openTypeIds};
          if (types.contains(typeId)) {
            types.remove(typeId);
          } else {
            types.add(typeId);
          }
          return p.withState(types);
        }
        return p;
      }).toList();
      currentSnapshot = InspectionSnapshot(
        plants: plants,
        types: currentSnapshot!.types,
        loadedAt: currentSnapshot!.loadedAt,
      );
    }
  }

  @override
  Future<LocalInspection?> finalizeInspection() async {
    finalizeCallCount++;
    return LocalInspection(
      id: 'final-1',
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      status: InspectionSyncStatus.pending,
      plantsCount: 1,
      changesCount: 1,
      payloadJson: '{}',
    );
  }

  @override
  Future<bool> syncPending() async => syncSucceeds;

  @override
  Future<List<LocalInspection>> listLocalInspections() async => localList;

  @override
  Future<List<InspectionChange>> getInspectionChanges(String inspectionId) async => [];

  int removePlantCallCount = 0;
  String? lastRemovedInspectionId;
  String? lastRemovedPlantId;

  @override
  Future<void> removePlantFromInspection(String inspectionId, String plantId) async {
    removePlantCallCount++;
    lastRemovedInspectionId = inspectionId;
    lastRemovedPlantId = plantId;
  }
}

void main() {
  late FakeLocationService locationService;
  late FakeInspectionRepo repo;
  late InspectionViewModel viewModel;

  setUp(() {
    locationService = FakeLocationService();
    repo = FakeInspectionRepo();
    viewModel = InspectionViewModel(
      repository: repo,
      locationService: locationService,
    );
  });

  tearDown(() {
    viewModel.dispose();
    locationService.dispose();
  });

  test('location handling for GPS states and messages', () async {
    viewModel.resumeLocation();

    locationService.emit(const LocationResult.permissionDenied());
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.locationMessage, contains('Permita o acesso'));
    expect(viewModel.canShowUserLocation, isFalse);

    locationService.emit(const LocationResult.serviceDisabled());
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.locationMessage, contains('Ative o serviço'));

    locationService.emit(const LocationResult.available(UserLocation(latitude: -23.5, longitude: -46.5)));
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.locationMessage, isNull);
    expect(viewModel.canShowUserLocation, isTrue);
    expect(viewModel.userLocation?.latitude, -23.5);
  });

  test('pausing and resuming location subscription avoids duplicate streams', () {
    viewModel.resumeLocation();
    expect(locationService.watchCallCount, 1);

    // Calling resume again while active should do nothing
    viewModel.resumeLocation();
    expect(locationService.watchCallCount, 1);

    viewModel.pauseLocation();
    viewModel.resumeLocation();
    expect(locationService.watchCallCount, 2);
  });

  test('loadPlants sets status correctly for success, empty, error', () async {
    repo.currentSnapshot = InspectionSnapshot(
      plants: [InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1)],
      types: [const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
      loadedAt: DateTime.now(),
    );

    await viewModel.loadPlants();
    expect(viewModel.loadStatus, InspectionLoadStatus.success);
    expect(viewModel.plants.length, 1);
    expect(viewModel.catalog.length, 1);

    // Empty
    repo.currentSnapshot = InspectionSnapshot(
      plants: [],
      types: [],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants();
    expect(viewModel.loadStatus, InspectionLoadStatus.empty);

    // Error
    repo.currentSnapshot = null;
    await viewModel.loadPlants();
    expect(viewModel.loadStatus, InspectionLoadStatus.empty);
  });

  test('togglePlantOccurrence updates plant state and feedback', () async {
    final plant = InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1);
    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant],
      types: [const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants();
    viewModel.selectPlant(viewModel.plants.first);

    await viewModel.togglePlantOccurrence('t-1');
    expect(repo.toggleCallCount, 1);
    expect(viewModel.selectedPlant?.openTypeIds, {'t-1'});
    expect(viewModel.feedbackMessage, 'Salvo no dispositivo');

    // Toggle again to remove
    await viewModel.togglePlantOccurrence('t-1');
    expect(repo.toggleCallCount, 2);
    expect(viewModel.selectedPlant?.openTypeIds, isEmpty);
  });

  test('finalizeInspection distinguishes sync success from pending save', () async {
    repo.syncSucceeds = true;
    await viewModel.finalizeInspection();
    expect(viewModel.feedbackMessage, 'Sincronizado com sucesso!');

    repo.syncSucceeds = false;
    await viewModel.finalizeInspection();
    expect(viewModel.feedbackMessage, contains('envio pendente'));
  });

  test('selectDiagnosticCode emits code', () {
    viewModel.selectDiagnosticCode('stick');
    expect(viewModel.diagnosticCode, 'stick');
  });

  test('toggleStagedOccurrence stages in memory without persisting until savePlantChangesAndFinalize', () async {
    final plant = InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1);
    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant],
      types: [const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants();
    viewModel.selectPlant(viewModel.plants.first);

    expect(viewModel.hasStagedChanges, isFalse);
    viewModel.toggleStagedOccurrence('t-1');
    expect(viewModel.hasStagedChanges, isTrue);
    expect(viewModel.isOccurrenceChecked('t-1'), isTrue);
    expect(repo.toggleCallCount, 0); // Not saved yet to device!

    await viewModel.savePlantChangesAndFinalize();
    expect(repo.toggleCallCount, 1);
    expect(repo.finalizeCallCount, 1);
  });

  test('deletePlantFromInspection removes plant and reloads state', () async {
    final plant = InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1);
    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant],
      types: [const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants();
    viewModel.selectPlant(viewModel.plants.first);

    await viewModel.deletePlantFromInspection(inspectionId: 'inspec-1', plantId: 'p-1');
    expect(repo.removePlantCallCount, 1);
    expect(repo.lastRemovedInspectionId, 'inspec-1');
    expect(repo.lastRemovedPlantId, 'p-1');
    expect(viewModel.feedbackMessage, 'Planta removida com sucesso');
  });

  test('filterByOccurrence filters plants in memory without new fetch and clearOccurrenceFilter restores all', () async {
    final plant1 = InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1, openTypeIds: {'t-1'});
    final plant2 = InspectionPlant(id: 'p-2', latitude: -23.2, longitude: -46.2, openTypeIds: {'t-2'});
    final plant3 = InspectionPlant(id: 'p-3', latitude: -23.3, longitude: -46.3, openTypeIds: {'t-1', 't-2'});
    final plant4 = InspectionPlant(id: 'p-4', latitude: -23.4, longitude: -46.4, openTypeIds: {});

    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant1, plant2, plant3, plant4],
      types: [
        const OccurrenceType(id: 't-1', name: 'Lagarta', code: 'caterpillar'),
        const OccurrenceType(id: 't-2', name: 'Pulgão', code: 'aphid'),
      ],
      loadedAt: DateTime.now(),
    );

    await viewModel.loadPlants();
    expect(viewModel.plants.length, 4);
    expect(viewModel.allPlants.length, 4);
    expect(viewModel.isFiltered, isFalse);

    // Filter by Lagarta (t-1)
    viewModel.filterByOccurrence('t-1');
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.selectedOccurrenceFilterId, 't-1');
    expect(viewModel.selectedOccurrenceFilter?.name, 'Lagarta');
    expect(viewModel.diagnosticCode, 'caterpillar');
    // Only p-1 and p-3 have t-1
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-1', 'p-3']);
    expect(viewModel.allPlants.length, 4);

    // Filter by Pulgão (t-2)
    viewModel.filterByOccurrence('t-2');
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-2', 'p-3']);

    // Clear filter (Mostrar todas)
    viewModel.clearOccurrenceFilter();
    expect(viewModel.isFiltered, isFalse);
    expect(viewModel.selectedOccurrenceFilterId, isNull);
    expect(viewModel.selectedOccurrenceFilter, isNull);
    expect(viewModel.diagnosticCode, isNull);
    expect(viewModel.plants.length, 4);
  });

  test('filterByZone and combined filtering works in memory without remote fetch', () async {
    viewModel.setZones([
      const Zone(id: 'z-1', name: 'Zona Norte', code: 'ZN'),
      const Zone(id: 'z-2', name: 'Zona Sul', code: 'ZS'),
    ]);

    final plant1 = InspectionPlant(id: 'p-1', zoneId: 'z-1', latitude: -23.1, longitude: -46.1, openTypeIds: {'t-1'});
    final plant2 = InspectionPlant(id: 'p-2', zoneId: 'z-1', latitude: -23.2, longitude: -46.2, openTypeIds: {'t-2'});
    final plant3 = InspectionPlant(id: 'p-3', zoneId: 'z-2', latitude: -23.3, longitude: -46.3, openTypeIds: {'t-1'});
    final plant4 = InspectionPlant(id: 'p-4', zoneId: 'z-2', latitude: -23.4, longitude: -46.4, openTypeIds: {});

    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant1, plant2, plant3, plant4],
      types: [
        const OccurrenceType(id: 't-1', name: 'Lagarta', code: 'caterpillar'),
        const OccurrenceType(id: 't-2', name: 'Pulgão', code: 'aphid'),
      ],
      loadedAt: DateTime.now(),
    );

    await viewModel.loadPlants();
    expect(viewModel.plants.length, 4);
    expect(viewModel.isFiltered, isFalse);

    // Filter by Zone z-1
    viewModel.filterByZone('z-1');
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.selectedZoneFilterId, 'z-1');
    expect(viewModel.selectedZoneFilter?.name, 'Zona Norte');
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-1', 'p-2']);

    // Combined filter: Zone z-1 AND Occurrence t-1
    viewModel.filterByOccurrence('t-1');
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-1']);

    // Switch to Zone z-2 with Occurrence t-1 still active
    viewModel.filterByZone('z-2');
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-3']);

    // Clear zone filter only
    viewModel.clearZoneFilter();
    expect(viewModel.selectedZoneFilterId, isNull);
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.plants.map((p) => p.id).toList(), ['p-1', 'p-3']);

    // Clear all filters
    viewModel.clearAllFilters();
    expect(viewModel.isFiltered, isFalse);
    expect(viewModel.selectedZoneFilterId, isNull);
    expect(viewModel.selectedOccurrenceFilterId, isNull);
    expect(viewModel.plants.length, 4);
  });

  test('zone polygon is generated when zone with regions is selected', () async {
    const zoneId = 'z-1';
    final regionPoints = [
      const RegionPoint(latitude: -23.1, longitude: -46.1, zoneId: zoneId),
      const RegionPoint(latitude: -23.1, longitude: -46.2, zoneId: zoneId),
      const RegionPoint(latitude: -23.2, longitude: -46.2, zoneId: zoneId),
      const RegionPoint(latitude: -23.2, longitude: -46.1, zoneId: zoneId),
    ];

    expect(viewModel.polygons, isEmpty);

    viewModel.setZonePoints(zoneId, regionPoints);
    expect(viewModel.polygons, isEmpty); // Not selected yet

    viewModel.filterByZone(zoneId);
    expect(viewModel.selectedZonePoints, regionPoints);
    expect(viewModel.polygons.length, 1);

    final polygon = viewModel.polygons.first;
    expect(polygon.polygonId.value, 'zone_z-1');
    expect(polygon.points.length, 4);

    viewModel.clearZoneFilter();
    expect(viewModel.selectedZonePoints, isEmpty);
    expect(viewModel.polygons, isEmpty);
  });
}
