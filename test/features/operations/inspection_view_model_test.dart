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
  Object? loadError;
  List<LocalInspection> localList = [];
  bool syncSucceeds = true;
  final List<AddedInspectionPlant> addedPlants = [];

  int toggleCallCount = 0;
  int finalizeCallCount = 0;
  int addPlantCallCount = 0;
  int syncAddedPlantsCallCount = 0;
  int removeAddedPlantCallCount = 0;

  @override
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false}) async {
    if (loadError case final error?) throw error;
    return currentSnapshot;
  }

  @override
  Future<List<OccurrenceType>> getCatalog() async =>
      currentSnapshot?.types ?? [];

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
  Future<bool> syncPendingAddedPlants() async {
    syncAddedPlantsCallCount++;
    if (syncSucceeds) {
      for (var i = 0; i < addedPlants.length; i++) {
        final plant = addedPlants[i];
        final remoteId = 'remote-${plant.localId}';
        addedPlants[i] = AddedInspectionPlant(
          localId: plant.localId,
          latitude: plant.latitude,
          longitude: plant.longitude,
          nonExistent: plant.nonExistent,
          status: InspectionSyncStatus.synced,
          createdAt: plant.createdAt,
          remotePlantId: remoteId,
          syncedAt: DateTime.now(),
          zoneId: plant.zoneId,
        );
        if (currentSnapshot != null &&
            !currentSnapshot!.plants.any((p) => p.id == remoteId)) {
          final updated = List<InspectionPlant>.from(currentSnapshot!.plants)
            ..add(
              InspectionPlant(
                id: remoteId,
                latitude: plant.latitude,
                longitude: plant.longitude,
                nonExistent: plant.nonExistent,
                zoneId: plant.zoneId,
              ),
            );
          currentSnapshot = InspectionSnapshot(
            plants: updated,
            types: currentSnapshot!.types,
            loadedAt: currentSnapshot!.loadedAt,
          );
        }
      }
    }
    return syncSucceeds;
  }

  @override
  Future<List<LocalInspection>> listLocalInspections() async => localList;

  @override
  Future<List<AddedInspectionPlant>> listAddedPlants() async => addedPlants;

  @override
  Future<void> removeAddedPlant(String localId) async {
    removeAddedPlantCallCount++;
    addedPlants.removeWhere((plant) => plant.localId == localId);
  }

  @override
  Future<List<InspectionChange>> getInspectionChanges(
    String inspectionId,
  ) async => [];

  int removePlantCallCount = 0;
  String? lastRemovedInspectionId;
  String? lastRemovedPlantId;

  int setPlantNonExistentCallCount = 0;
  String? lastNonExistentPlantId;
  bool? lastNonExistentValue;

  @override
  Future<void> setPlantNonExistent(String plantId, bool nonExistent) async {
    setPlantNonExistentCallCount++;
    lastNonExistentPlantId = plantId;
    lastNonExistentValue = nonExistent;
    if (currentSnapshot != null) {
      final plants = currentSnapshot!.plants.map((p) {
        if (p.id == plantId) {
          return p.withState(
            p.openTypeIds,
            eligible: true,
            nonExistent: nonExistent,
          );
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
  Future<AddedInspectionPlant> addPlant({
    required double latitude,
    required double longitude,
    required bool nonExistent,
    String? zoneId,
  }) async {
    addPlantCallCount++;
    final plant = AddedInspectionPlant(
      localId: 'added-${addedPlants.length + 1}',
      latitude: latitude,
      longitude: longitude,
      nonExistent: nonExistent,
      status: InspectionSyncStatus.pending,
      createdAt: DateTime.now(),
      zoneId: zoneId,
    );
    addedPlants.insert(0, plant);
    return plant;
  }

  @override
  Future<void> removePlantFromInspection(
    String inspectionId,
    String plantId,
  ) async {
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

    locationService.emit(
      const LocationResult.available(
        UserLocation(latitude: -23.5, longitude: -46.5),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.locationMessage, isNull);
    expect(viewModel.canShowUserLocation, isTrue);
    expect(viewModel.userLocation?.latitude, -23.5);
  });

  test('initialization cannot reactivate GPS on a hidden route', () async {
    viewModel.pauseLocation();
    await viewModel.initialize();
    expect(locationService.watchCallCount, 0);
    viewModel.resumeLocation();
    viewModel.pauseLocation();
    await viewModel.initialize();
    expect(locationService.watchCallCount, 1);
  });

  test(
    'pausing and resuming location subscription avoids duplicate streams',
    () {
      viewModel.resumeLocation();
      expect(locationService.watchCallCount, 1);

      // Calling resume again while active should do nothing
      viewModel.resumeLocation();
      expect(locationService.watchCallCount, 1);

      viewModel.pauseLocation();
      viewModel.resumeLocation();
      expect(locationService.watchCallCount, 2);
    },
  );

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

  test(
    'keeps previous plants visible when an explicit refresh fails',
    () async {
      repo.currentSnapshot = InspectionSnapshot(
        plants: [InspectionPlant(id: 'p-1', latitude: -23.1, longitude: -46.1)],
        types: [const OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
        loadedAt: DateTime.now(),
      );
      await viewModel.loadPlants();

      repo.loadError = Exception('offline');
      await viewModel.loadPlants();

      expect(viewModel.loadStatus, InspectionLoadStatus.error);
      expect(viewModel.allPlants.single.id, 'p-1');
      expect(viewModel.errorMessage, 'Não foi possível carregar as plantas.');
    },
  );

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

  test(
    'finalizeInspection distinguishes sync success from pending save',
    () async {
      repo.syncSucceeds = true;
      await viewModel.finalizeInspection();
      expect(viewModel.feedbackMessage, 'Sincronizado com sucesso!');

      repo.syncSucceeds = false;
      await viewModel.finalizeInspection();
      expect(viewModel.feedbackMessage, contains('envio pendente'));
    },
  );

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

    await viewModel.deletePlantFromInspection(
      inspectionId: 'inspec-1',
      plantId: 'p-1',
    );
    expect(repo.removePlantCallCount, 1);
    expect(repo.lastRemovedInspectionId, 'inspec-1');
    expect(repo.lastRemovedPlantId, 'p-1');
    expect(viewModel.feedbackMessage, 'Planta removida com sucesso');
  });

  test('addPlantAt stores added plant without changing local inspections', () async {
    viewModel.setZones([
      const Zone(id: 'zone-1', name: 'Zona 1', code: 'Z1'),
    ]);
    viewModel.filterByZone('zone-1');
    repo.localList = [
      LocalInspection(
        id: 'draft-1',
        startedAt: DateTime.now(),
        status: InspectionSyncStatus.pending,
        plantsCount: 1,
        changesCount: 1,
      ),
    ];
    await viewModel.refreshLocalInspections();

    await viewModel.addPlantAt(
      latitude: -23.45,
      longitude: -46.67,
      nonExistent: true,
    );

    expect(repo.addPlantCallCount, 1);
    expect(viewModel.addedPlants, hasLength(1));
    expect(viewModel.addedPlants.single.nonExistent, isTrue);
    expect(viewModel.addedPlants.single.zoneId, 'zone-1');
    expect(viewModel.localInspections, hasLength(1));
    expect(viewModel.feedbackMessage, 'Planta salva no dispositivo');
  });

  test('syncPendingAddedPlants refreshes separate queue and feedback', () async {
    await viewModel.addPlantAt(
      latitude: -23.45,
      longitude: -46.67,
      nonExistent: false,
      zoneId: 'zone-2',
    );

    await viewModel.syncPendingAddedPlants();

    expect(repo.syncAddedPlantsCallCount, 1);
    expect(viewModel.addedPlants.single.status, InspectionSyncStatus.synced);
    expect(viewModel.addedPlants.single.remotePlantId, 'remote-added-1');
    expect(viewModel.allPlants.map((plant) => plant.id), contains('remote-added-1'));
    expect(viewModel.plantById('remote-added-1')?.latitude, -23.45);
    expect(viewModel.plantById('remote-added-1')?.longitude, -46.67);
    expect(viewModel.plantById('remote-added-1')?.zoneId, 'zone-2');
    expect(viewModel.feedbackMessage, 'Plantas sincronizadas com sucesso!');
  });

  test('removeAddedPlant refreshes separate queue', () async {
    await viewModel.addPlantAt(
      latitude: -23.45,
      longitude: -46.67,
      nonExistent: false,
    );
    final localId = viewModel.addedPlants.single.localId;

    await viewModel.removeAddedPlant(localId);

    expect(repo.removeAddedPlantCallCount, 1);
    expect(viewModel.addedPlants, isEmpty);
    expect(viewModel.feedbackMessage, 'Planta adicionada removida');
  });

  test('filterByOccurrence filters plants in memory without new fetch and clearOccurrenceFilter restores all', () async {
    final plant1 = InspectionPlant(
      id: 'p-1',
      latitude: -23.1,
      longitude: -46.1,
      openTypeIds: {'t-1'},
    );
    final plant2 = InspectionPlant(
      id: 'p-2',
      latitude: -23.2,
      longitude: -46.2,
      openTypeIds: {'t-2'},
    );
    final plant3 = InspectionPlant(
      id: 'p-3',
      latitude: -23.3,
      longitude: -46.3,
      openTypeIds: {'t-1', 't-2'},
    );
    final plant4 = InspectionPlant(
      id: 'p-4',
      latitude: -23.4,
      longitude: -46.4,
      openTypeIds: {},
    );

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

  test(
    'filterByZone and combined filtering works in memory without remote fetch',
    () async {
      viewModel.setZones([
        const Zone(id: 'z-1', name: 'Zona Norte', code: 'ZN'),
        const Zone(id: 'z-2', name: 'Zona Sul', code: 'ZS'),
      ]);

      final plant1 = InspectionPlant(
        id: 'p-1',
        zoneId: 'z-1',
        latitude: -23.1,
        longitude: -46.1,
        openTypeIds: {'t-1'},
      );
      final plant2 = InspectionPlant(
        id: 'p-2',
        zoneId: 'z-1',
        latitude: -23.2,
        longitude: -46.2,
        openTypeIds: {'t-2'},
      );
      final plant3 = InspectionPlant(
        id: 'p-3',
        zoneId: 'z-2',
        latitude: -23.3,
        longitude: -46.3,
        openTypeIds: {'t-1'},
      );
      final plant4 = InspectionPlant(
        id: 'p-4',
        zoneId: 'z-2',
        latitude: -23.4,
        longitude: -46.4,
        openTypeIds: {},
      );

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
    },
  );

  test(
    'zone polygon is generated when zone with regions is selected',
    () async {
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
    },
  );

  test('stagedNonExistent is initialized from plant and toggles correctly', () async {
    final plant = InspectionPlant(
      id: 'p-toggle',
      latitude: -23.1,
      longitude: -46.1,
      nonExistent: false,
    );
    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant],
      types: const [],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants(forceRemote: false);

    viewModel.selectPlant(plant);
    expect(viewModel.stagedNonExistent, isFalse);
    expect(viewModel.hasStagedChanges, isFalse);

    viewModel.toggleStagedNonExistent(true);
    expect(viewModel.stagedNonExistent, isTrue);
    expect(viewModel.hasStagedChanges, isTrue);

    viewModel.toggleStagedNonExistent();
    expect(viewModel.stagedNonExistent, isFalse);
    expect(viewModel.hasStagedChanges, isFalse);
  });

  test('savePlantChanges persists nonExistent flag when changed', () async {
    final plant = InspectionPlant(
      id: 'p-save-non-existent',
      latitude: -23.1,
      longitude: -46.1,
      nonExistent: false,
    );
    repo.currentSnapshot = InspectionSnapshot(
      plants: [plant],
      types: const [],
      loadedAt: DateTime.now(),
    );
    await viewModel.loadPlants(forceRemote: false);

    viewModel.selectPlant(plant);
    viewModel.toggleStagedNonExistent(true);
    expect(viewModel.hasStagedChanges, isTrue);

    await viewModel.savePlantChanges();

    expect(repo.setPlantNonExistentCallCount, 1);
    expect(repo.lastNonExistentPlantId, 'p-save-non-existent');
    expect(repo.lastNonExistentValue, isTrue);
    expect(viewModel.selectedPlant?.nonExistent, isTrue);
    expect(viewModel.hasStagedChanges, isFalse);
  });

  test(
    'synced added plant persists in plants list after finalizing inspection',
    () async {
      final existingPlant = InspectionPlant(
        id: 'p-existing',
        latitude: -23.1,
        longitude: -46.1,
        nonExistent: false,
      );
      repo.currentSnapshot = InspectionSnapshot(
        plants: [existingPlant],
        types: const [OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
        loadedAt: DateTime.now(),
      );
      await viewModel.loadPlants(forceRemote: false);
      expect(viewModel.plants, hasLength(1));

      // Add a new plant point
      await viewModel.addPlantAt(
        latitude: -23.2,
        longitude: -46.2,
        nonExistent: false,
        zoneId: 'z-1',
      );
      expect(viewModel.addedPlants, hasLength(1));

      // Sync the added plant
      await viewModel.syncPendingAddedPlants();
      expect(viewModel.addedPlants.single.status, InspectionSyncStatus.synced);
      final remoteId = viewModel.addedPlants.single.remotePlantId!;
      expect(viewModel.plants.any((p) => p.id == remoteId), isTrue);

      // Add occurrence to existing plant and finalize inspection
      viewModel.selectPlant(existingPlant);
      viewModel.toggleStagedOccurrence('t-1');
      await viewModel.savePlantChangesAndFinalize();

      // Verify the newly added plant remains in viewModel.plants!
      expect(viewModel.plants.any((p) => p.id == remoteId), isTrue);
      expect(viewModel.plantById(remoteId), isNotNull);
    },
  );

  test(
    'occurrences can be added to newly added synced plant and saved',
    () async {
      repo.currentSnapshot = InspectionSnapshot(
        plants: [],
        types: const [OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
        loadedAt: DateTime.now(),
      );
      await viewModel.loadPlants(forceRemote: false);

      await viewModel.addPlantAt(
        latitude: -23.3,
        longitude: -46.3,
        nonExistent: false,
      );
      await viewModel.syncPendingAddedPlants();

      final remoteId = viewModel.addedPlants.single.remotePlantId!;
      final newPlant = viewModel.plantById(remoteId);
      expect(newPlant, isNotNull);

      // Select newly added plant and add occurrence
      viewModel.selectPlant(newPlant!);
      viewModel.toggleStagedOccurrence('t-1');
      expect(viewModel.hasStagedChanges, isTrue);

      await viewModel.savePlantChanges();
      expect(repo.toggleCallCount, 1);
      expect(viewModel.feedbackMessage, 'Salvo no dispositivo');
      expect(viewModel.selectedPlant?.openTypeIds.contains('t-1'), isTrue);
    },
  );

  test(
    'toggleStagedOccurrence is ignored when stagedNonExistent is true',
    () async {
      final plant = InspectionPlant(
        id: 'p-disabled-occ',
        latitude: -23.1,
        longitude: -46.1,
        nonExistent: false,
      );
      repo.currentSnapshot = InspectionSnapshot(
        plants: [plant],
        types: const [OccurrenceType(id: 't-1', name: 'Praga', code: 'pest')],
        loadedAt: DateTime.now(),
      );
      await viewModel.loadPlants(forceRemote: false);

      viewModel.selectPlant(plant);
      expect(viewModel.isOccurrenceChecked('t-1'), isFalse);

      // Mark plant as non-existent
      viewModel.toggleStagedNonExistent(true);
      expect(viewModel.stagedNonExistent, isTrue);

      // Attempt to toggle occurrence
      viewModel.toggleStagedOccurrence('t-1');
      expect(viewModel.isOccurrenceChecked('t-1'), isFalse);

      // Untoggle non-existent and toggle should work again
      viewModel.toggleStagedNonExistent(false);
      viewModel.toggleStagedOccurrence('t-1');
      expect(viewModel.isOccurrenceChecked('t-1'), isTrue);
    },
  );
}


