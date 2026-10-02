import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view_model.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/inspection_filters_modal.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/local_inspections_modal.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/plant_editor_modal.dart';

class FakeLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.available(UserLocation(latitude: -23.1, longitude: -46.1));

  @override
  Stream<LocationResult> watchLocation() => Stream.value(
        const LocationResult.available(UserLocation(latitude: -23.1, longitude: -46.1)),
      );
}

class FakeWidgetInspectionRepository implements InspectionRepository {
  InspectionSnapshot snapshot = InspectionSnapshot(
    plants: [
      InspectionPlant(id: 'plant-1', latitude: -23.1, longitude: -46.1, description: 'Planta 1'),
      InspectionPlant(id: 'plant-2', latitude: -23.2, longitude: -46.2, description: 'Planta 2'),
    ],
    types: const [
      OccurrenceType(id: 'type-1', name: 'Lagarta', code: 'caterpillar'),
      OccurrenceType(id: 'type-2', name: 'Pulgão', code: 'aphid'),
    ],
    loadedAt: DateTime.now(),
  );

  final List<LocalInspection> inspections = [];
  final List<AddedInspectionPlant> addedPlants = [];
  int finalizeCalls = 0;
  int syncCalls = 0;
  int syncAddedPlantsCalls = 0;
  int removeAddedPlantCalls = 0;

  @override
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false}) async => snapshot;

  @override
  Future<List<OccurrenceType>> getCatalog() async => snapshot.types;

  @override
  Future<void> togglePlantOccurrence(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  }) async {
    final updated = snapshot.plants.map((p) {
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
    snapshot = InspectionSnapshot(
      plants: updated,
      types: snapshot.types,
      loadedAt: snapshot.loadedAt,
    );

    // Update draft inspection in list
    inspections.removeWhere((i) => i.isDraft);
    inspections.insert(
      0,
      LocalInspection(
        id: 'draft-1',
        startedAt: DateTime.now(),
        status: InspectionSyncStatus.pending,
        plantsCount: snapshot.plants.where((p) => p.openTypeIds.isNotEmpty).length,
        changesCount: 1,
      ),
    );
  }

  @override
  Future<LocalInspection?> finalizeInspection() async {
    finalizeCalls++;
    final changedPlants = snapshot.plants.where((p) => p.openTypeIds.isNotEmpty).length;
    inspections.removeWhere((i) => i.isDraft);
    final finalized = LocalInspection(
      id: 'final-1',
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      status: InspectionSyncStatus.synced,
      plantsCount: changedPlants,
      changesCount: 2,
      remoteId: 'op-remote-123',
      syncedAt: DateTime.now(),
      payloadJson: '{}',
    );
    inspections.insert(0, finalized);
    return finalized;
  }

  @override
  Future<bool> syncPending() async {
    syncCalls++;
    return true;
  }

  @override
  Future<bool> syncPendingAddedPlants() async {
    syncAddedPlantsCalls++;
    for (var i = 0; i < addedPlants.length; i++) {
      final plant = addedPlants[i];
      if (plant.status == InspectionSyncStatus.pending ||
          plant.status == InspectionSyncStatus.error) {
        addedPlants[i] = AddedInspectionPlant(
          localId: plant.localId,
          latitude: plant.latitude,
          longitude: plant.longitude,
          nonExistent: plant.nonExistent,
          status: InspectionSyncStatus.synced,
          createdAt: plant.createdAt,
          remotePlantId: 'remote-${plant.localId}',
          syncedAt: DateTime.now(),
          zoneId: plant.zoneId,
        );
      }
    }
    return true;
  }

  @override
  Future<List<LocalInspection>> listLocalInspections() async => inspections;

  @override
  Future<List<AddedInspectionPlant>> listAddedPlants() async => addedPlants;

  @override
  Future<void> removeAddedPlant(String localId) async {
    removeAddedPlantCalls++;
    addedPlants.removeWhere((plant) => plant.localId == localId);
  }

  @override
  Future<List<InspectionChange>> getInspectionChanges(String inspectionId) async => [
    InspectionChange(
      id: 'ch-1',
      plantId: 'plant-1',
      typeId: 'type-1',
      added: true,
      sequence: 1,
      changedAt: DateTime.now(),
    ),
    InspectionChange(
      id: 'ch-2',
      plantId: 'plant-2',
      typeId: 'type-2',
      added: true,
      sequence: 2,
      changedAt: DateTime.now(),
    ),
  ];

  int removePlantCalls = 0;
  int setNonExistentCalls = 0;

  @override
  Future<void> setPlantNonExistent(String plantId, bool nonExistent) async {
    setNonExistentCalls++;
    final updated = snapshot.plants.map((p) {
      if (p.id == plantId) {
        return p.withState(
          p.openTypeIds,
          eligible: true,
          nonExistent: nonExistent,
        );
      }
      return p;
    }).toList();
    snapshot = InspectionSnapshot(
      plants: updated,
      types: snapshot.types,
      loadedAt: snapshot.loadedAt,
    );
  }

  @override
  Future<AddedInspectionPlant> addPlant({
    required double latitude,
    required double longitude,
    required bool nonExistent,
    String? zoneId,
  }) async {
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
  Future<void> removePlantFromInspection(String inspectionId, String plantId) async {
    removePlantCalls++;
    final index = inspections.indexWhere((i) => i.id == inspectionId);
    if (index != -1) {
      final current = inspections[index];
      if (current.plantsCount <= 1) {
        inspections.removeAt(index);
      } else {
        inspections[index] = LocalInspection(
          id: current.id,
          startedAt: current.startedAt,
          finishedAt: current.finishedAt,
          status: current.status,
          plantsCount: current.plantsCount - 1,
          changesCount: current.changesCount - 1,
          remoteId: current.remoteId,
          error: current.error,
          payloadJson: current.payloadJson,
        );
      }
    }
  }
}

Widget buildTestWidget({
  required InspectionViewModel viewModel,
  InspectionMapBuilder? mapBuilder,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
      useMaterial3: true,
    ),
    home: InspectionView(
      viewModel: viewModel,
      mapBuilder: mapBuilder ??
          (context, config) {
            return ListView.builder(
              key: const ValueKey('fake-map-plants-list'),
              itemCount: config.plants.length,
              itemBuilder: (context, index) {
                final plant = config.plants[index];
                return ListTile(
                  key: ValueKey('map-plant-${plant.id}'),
                  title: Text(plant.label),
                  onTap: () => config.onSelectPlant(plant),
                );
              },
            );
          },
    ),
  );
}

void main() {
  late FakeWidgetInspectionRepository repo;
  late FakeLocationService locationService;
  late InspectionViewModel viewModel;

  setUp(() {
    repo = FakeWidgetInspectionRepository();
    locationService = FakeLocationService();
    viewModel = InspectionViewModel(
      repository: repo,
      locationService: locationService,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  testWidgets('action card touch targets and responsiveness at 320, 768, 1024 px', (tester) async {
    for (final width in [320.0, 768.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
      await tester.pumpAndSettle();

      for (final key in [
        'action-load-plants',
        'action-occurrences',
        'action-added-plants',
        'action-saved-inspections',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('map long press opens added plant modal and double tap removes it', (tester) async {
    viewModel.setZones([
      const Zone(id: 'zone-1', name: 'Talhao 1', code: 'T1'),
      const Zone(id: 'zone-2', name: 'Talhao 2', code: 'T2'),
    ]);
    viewModel.filterByZone('zone-1');
    await tester.pumpWidget(
      buildTestWidget(
        viewModel: viewModel,
        mapBuilder: (context, config) {
          return Column(
            children: [
              const SizedBox(height: 120),
              ElevatedButton(
                key: const ValueKey('fake-map-long-press-button'),
                onPressed: () => config.onMapLongPress(
                  const LatLng(-23.456789, -46.654321),
                ),
                child: const Text('Long press map'),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final plant in config.addedPlants)
                      GestureDetector(
                        key: ValueKey('fake-added-marker-${plant.localId}'),
                        onDoubleTap: () => config.onRemoveAddedPlant(plant),
                        child: Text(
                          '${plant.latitude.toStringAsFixed(6)}, ${plant.longitude.toStringAsFixed(6)}',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fake-map-long-press-button')));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar planta'), findsOneWidget);
    expect(find.text('Talhao 1'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.addedPlants, isEmpty);

    await tester.tap(find.byKey(const ValueKey('fake-map-long-press-button')));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar planta'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Select Talhao 2 from dropdown
    await tester.tap(find.byKey(const ValueKey('added-plant-zone-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talhao 2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('confirm-added-plant-button')));
    await tester.pumpAndSettle();

    expect(repo.addedPlants, hasLength(1));
    expect(repo.addedPlants.single.nonExistent, isTrue);
    expect(repo.addedPlants.single.zoneId, 'zone-2');
    expect(find.byKey(ValueKey('fake-added-marker-${repo.addedPlants.single.localId}')), findsOneWidget);
    expect(repo.inspections, isEmpty);

    await tester.tap(find.byKey(ValueKey('fake-added-marker-${repo.addedPlants.single.localId}')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(ValueKey('fake-added-marker-${repo.addedPlants.single.localId}')));
    await tester.pumpAndSettle();

    expect(repo.removeAddedPlantCalls, 1);
    expect(repo.addedPlants, isEmpty);
  });

  testWidgets('added plants modal lists states and syncs separately', (tester) async {
    repo.addedPlants.addAll([
      AddedInspectionPlant(
        localId: 'added-pending',
        latitude: -23.45,
        longitude: -46.67,
        nonExistent: false,
        status: InspectionSyncStatus.pending,
        createdAt: DateTime.now(),
      ),
      AddedInspectionPlant(
        localId: 'added-error',
        latitude: -23.46,
        longitude: -46.68,
        nonExistent: true,
        status: InspectionSyncStatus.error,
        createdAt: DateTime.now(),
        error: 'Falha',
      ),
      AddedInspectionPlant(
        localId: 'added-synced',
        latitude: -23.47,
        longitude: -46.69,
        nonExistent: false,
        status: InspectionSyncStatus.synced,
        createdAt: DateTime.now(),
        remotePlantId: 'remote-added-synced',
        syncedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();
    await viewModel.refreshAddedPlants();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('action-added-plants')));
    await tester.pumpAndSettle();

    expect(find.text('Plantas adicionadas'), findsOneWidget);
    expect(find.byKey(const ValueKey('local-added-plants-list')), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Erro no envio'), findsOneWidget);
    expect(find.text('Sincronizada'), findsOneWidget);
    expect(find.text('Inexistente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sync-added-plants-button')));
    await tester.pumpAndSettle();

    expect(repo.syncAddedPlantsCalls, 1);
    expect(repo.addedPlants.map((p) => p.status).toSet(), {
      InspectionSyncStatus.synced,
    });

    await tester.tap(find.byKey(const ValueKey('local-added-plant-added-pending')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('local-added-plant-added-pending')));
    await tester.pumpAndSettle();

    expect(repo.removeAddedPlantCalls, 1);
    expect(
      repo.addedPlants.map((plant) => plant.localId),
      isNot(contains('added-pending')),
    );
  });

  testWidgets('occurrence catalog opens, filters plants on map, and allows clearing filter with Mostrar todas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 840));
    tester.view.physicalSize = const Size(420, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    repo.snapshot = InspectionSnapshot(
      plants: [
        InspectionPlant(id: 'plant-1', latitude: -23.1, longitude: -46.1, description: 'Planta 1', openTypeIds: {'type-1'}),
        InspectionPlant(id: 'plant-2', latitude: -23.2, longitude: -46.2, description: 'Planta 2'),
      ],
      types: const [
        OccurrenceType(id: 'type-1', name: 'Lagarta', code: 'caterpillar'),
        OccurrenceType(id: 'type-2', name: 'Pulgão', code: 'aphid'),
      ],
      loadedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await viewModel.loadPlants();
    await tester.pumpAndSettle();

    // Initially both plants are on the map
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action-occurrences')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionFiltersModal), findsOneWidget);

    // Expand occurrences section
    await tester.tap(find.byKey(const ValueKey('toggle-occurrences-filter-section')));
    await tester.pumpAndSettle();

    expect(find.text('Mostrar todas'), findsOneWidget);
    expect(find.text('Lagarta'), findsOneWidget);
    expect(find.text('Pulgão'), findsOneWidget);

    // Tap Lagarta (type-1) to filter
    await tester.tap(find.byKey(const ValueKey('catalog-type-caterpillar')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionFiltersModal), findsNothing);
    expect(viewModel.diagnosticCode, 'caterpillar');
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.selectedOccurrenceFilterId, 'type-1');

    // On the map, only plant-1 is shown
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsNothing);
    expect(find.textContaining('Lagarta (1)'), findsOneWidget);

    // Clear filter using the badge clear button
    await tester.tap(find.byKey(const ValueKey('clear-occurrence-filter-button')));
    await tester.pumpAndSettle();

    expect(viewModel.isFiltered, isFalse);
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsOneWidget);

    // Open filter modal again and expand occurrences to filter by Lagarta
    await tester.tap(find.byKey(const ValueKey('action-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-occurrences-filter-section')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-type-caterpillar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsNothing);

    // Open filter modal again and tap "Mostrar todas"
    await tester.tap(find.byKey(const ValueKey('action-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-type-all')));
    await tester.pumpAndSettle();

    expect(viewModel.isFiltered, isFalse);
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsOneWidget);
  });

  testWidgets('filters modal filters plants by zone using dropdown and clears', (tester) async {
    viewModel.setZones([
      const Zone(id: 'zone-a', name: 'Talhão A', code: 'TA'),
      const Zone(id: 'zone-b', name: 'Talhão B', code: 'TB'),
    ]);
    repo.snapshot = InspectionSnapshot(
      plants: [
        InspectionPlant(id: 'plant-1', zoneId: 'zone-a', latitude: -23.1, longitude: -46.1, description: 'Planta 1'),
        InspectionPlant(id: 'plant-2', zoneId: 'zone-b', latitude: -23.2, longitude: -46.2, description: 'Planta 2'),
      ],
      types: const [],
      loadedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await viewModel.loadPlants();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsOneWidget);

    viewModel.setZonePoints('zone-a', const [
      RegionPoint(latitude: -23.1, longitude: -46.1, zoneId: 'zone-a'),
      RegionPoint(latitude: -23.1, longitude: -46.2, zoneId: 'zone-a'),
      RegionPoint(latitude: -23.2, longitude: -46.2, zoneId: 'zone-a'),
      RegionPoint(latitude: -23.2, longitude: -46.1, zoneId: 'zone-a'),
    ]);

    // Open filters modal
    await tester.tap(find.byKey(const ValueKey('action-filters')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionFiltersModal), findsOneWidget);

    // Tap the dropdown and select 'Talhão A'
    await tester.tap(find.byKey(const ValueKey('filter-zone-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talhão A').last);
    await tester.pumpAndSettle();

    // Close modal using the apply button
    await tester.tap(find.byKey(const ValueKey('apply-filters-button')));
    await tester.pumpAndSettle();

    expect(viewModel.selectedZoneFilterId, 'zone-a');
    expect(viewModel.isFiltered, isTrue);
    expect(viewModel.polygons.length, 1);
    expect(viewModel.polygons.first.polygonId.value, 'zone_zone-a');
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsNothing);

    // Clear filter
    await tester.tap(find.byKey(const ValueKey('clear-occurrence-filter-button')));
    await tester.pumpAndSettle();

    expect(viewModel.isFiltered, isFalse);
    expect(viewModel.polygons, isEmpty);
    expect(find.byKey(const ValueKey('map-plant-plant-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-plant-plant-2')), findsOneWidget);
  });

  testWidgets('plant editor allows multiselect toggles and updating', (tester) async {
    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await viewModel.loadPlants();
    await tester.pumpAndSettle();

    // Tap plant 1 from fake map
    await tester.tap(find.byKey(const ValueKey('map-plant-plant-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PlantEditorModal), findsOneWidget);
    expect(
      find.descendant(of: find.byType(PlantEditorModal), matching: find.text('Planta 1')),
      findsOneWidget,
    );

    // Toggle Lagarta
    await tester.tap(find.byKey(const ValueKey('occurrence-toggle-caterpillar')));
    await tester.pumpAndSettle();
    expect(viewModel.stagedOccurrenceTypeIds, {'type-1'});

    // Toggle Pulgão
    await tester.tap(find.byKey(const ValueKey('occurrence-toggle-aphid')));
    await tester.pumpAndSettle();
    expect(viewModel.stagedOccurrenceTypeIds, {'type-1', 'type-2'});

    // Untoggle Lagarta
    await tester.tap(find.byKey(const ValueKey('occurrence-toggle-caterpillar')));
    await tester.pumpAndSettle();
    expect(viewModel.stagedOccurrenceTypeIds, {'type-2'});

    // Close modal
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(PlantEditorModal), findsNothing);

    // Now edit Plant 2 and tap Atualizar to finalize both
    await tester.tap(find.byKey(const ValueKey('map-plant-plant-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('occurrence-toggle-caterpillar')));
    await tester.pumpAndSettle();

    // Fixed footer Atualizar button
    final updateButton = find.byKey(const ValueKey('plant-editor-update-button'));
    expect(updateButton, findsOneWidget);
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    expect(find.byType(PlantEditorModal), findsNothing);
  });

  testWidgets('saved inspections modal lists saved records, altered plants and statuses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    repo.inspections.addAll([
      LocalInspection(
        id: 'inspect-1',
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        finishedAt: DateTime.now().subtract(const Duration(minutes: 50)),
        status: InspectionSyncStatus.synced,
        plantsCount: 2,
        changesCount: 3,
        remoteId: 'op-101',
      ),
      LocalInspection(
        id: 'inspect-2',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        status: InspectionSyncStatus.error,
        plantsCount: 2,
        changesCount: 2,
        error: 'Network error',
      ),
    ]);

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('action-saved-inspections')));
    await tester.pumpAndSettle();

    expect(find.byType(LocalInspectionsModal), findsOneWidget);
    expect(find.text('Inspeções Salvas'), findsOneWidget);
    expect(find.text('2 plantas alteradas (3 alterações)'), findsOneWidget);
    expect(find.text('Sincronizada'), findsOneWidget);
    expect(find.text('Erro no envio'), findsOneWidget);
    expect(find.text('Sem internet'), findsOneWidget);
    expect(find.text('Plantas alteradas:'), findsNothing);
    expect(find.textContaining('Ver plantas alteradas'), findsWidgets);

    // Tap to expand altered plants for inspect-1
    await tester.tap(find.byKey(const ValueKey('toggle-altered-plants-inspect-1')));
    await tester.pumpAndSettle();
    expect(find.text('Plantas alteradas:'), findsOneWidget);

    // Verify delete button is disabled for inspect-1 (synced)
    final syncedDeleteBtn = tester.widget<IconButton>(find.byKey(const ValueKey('delete-plant-inspect-1-plant-1')));
    expect(syncedDeleteBtn.onPressed, isNull);

    // Collapse inspect-1
    await tester.tap(find.byKey(const ValueKey('toggle-altered-plants-inspect-1')));
    await tester.pumpAndSettle();

    // Tap to expand altered plants for inspect-2
    final toggleInspect2 = find.byKey(const ValueKey('toggle-altered-plants-inspect-2'));
    await tester.ensureVisible(toggleInspect2);
    await tester.pumpAndSettle();
    await tester.tap(toggleInspect2);
    await tester.pumpAndSettle();

    // Delete plant-1 from inspect-2 (unsynced)
    final unsyncedDeleteBtn = find.byKey(const ValueKey('delete-plant-inspect-2-plant-1'));
    await tester.ensureVisible(unsyncedDeleteBtn);
    await tester.pumpAndSettle();
    expect(unsyncedDeleteBtn, findsOneWidget);
    await tester.tap(unsyncedDeleteBtn);
    await tester.pumpAndSettle();

    // Confirm dialog is shown and confirm deletion
    expect(find.text('Excluir planta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-plant-button')));
    await tester.pumpAndSettle();
    expect(repo.removePlantCalls, 1);

    // Tap sync pending
    final syncButton = find.byKey(const ValueKey('sync-all-pending-button'));
    expect(syncButton, findsOneWidget);
    await tester.tap(syncButton);
    await tester.pumpAndSettle();
    expect(repo.syncCalls, 1);
  });

  testWidgets('PlantEditorModal renders Planta Inexistente toggle and enables update when toggled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await viewModel.loadPlants();
    await tester.pumpAndSettle();

    // Tap plant 1 from fake map
    await tester.tap(find.byKey(const ValueKey('map-plant-plant-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PlantEditorModal), findsOneWidget);

    final toggleFinder = find.byKey(const ValueKey('plant-non-existent-toggle'));
    expect(toggleFinder, findsOneWidget);
    expect(find.text('Planta Inexistente'), findsOneWidget);

    // Initial state is false
    final switchWidgetBefore = tester.widget<SwitchListTile>(toggleFinder);
    expect(switchWidgetBefore.value, isFalse);

    // Update button should be disabled before any changes
    final updateButtonFinder = find.byKey(const ValueKey('plant-editor-update-button'));
    final updateButtonBefore = tester.widget<FilledButton>(updateButtonFinder);
    expect(updateButtonBefore.onPressed, isNull);

    // Tap the toggle
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    // Toggle is now true
    final switchWidgetAfter = tester.widget<SwitchListTile>(toggleFinder);
    expect(switchWidgetAfter.value, isTrue);

    // Verify occurrences are disabled when Planta Inexistente is checked
    final ignorePointerFinder =
        find.byKey(const ValueKey('plant-occurrences-ignore-pointer'));
    expect(ignorePointerFinder, findsOneWidget);
    expect(tester.widget<IgnorePointer>(ignorePointerFinder).ignoring, isTrue);

    // Try tapping an occurrence; it must not be checked
    final firstOccurrenceFinder = find.byKey(const ValueKey('occurrence-toggle-greening'));
    if (firstOccurrenceFinder.evaluate().isNotEmpty) {
      await tester.tap(firstOccurrenceFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(viewModel.isOccurrenceChecked('t-1'), isFalse);
    }

    // Update button is now enabled
    final updateButtonAfter = tester.widget<FilledButton>(updateButtonFinder);
    expect(updateButtonAfter.onPressed, isNotNull);

    // Tap update button to save
    await tester.tap(updateButtonFinder);
    await tester.pumpAndSettle();

    expect(repo.setNonExistentCalls, 1);
    expect(find.byType(PlantEditorModal), findsNothing);
  });

  testWidgets('nonExistent plants appear on map and toggle starts active when opened', (tester) async {
    repo.snapshot = InspectionSnapshot(
      plants: [
        InspectionPlant(
          id: 'plant-non-exist',
          latitude: -23.1,
          longitude: -46.1,
          description: 'Planta Inexistente Teste',
          nonExistent: true,
        ),
      ],
      types: repo.snapshot.types,
      loadedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(viewModel: viewModel));
    await tester.pumpAndSettle();

    await viewModel.loadPlants();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-plant-plant-non-exist')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-plant-plant-non-exist')));
    await tester.pumpAndSettle();

    expect(find.byType(PlantEditorModal), findsOneWidget);

    final toggleFinder = find.byKey(const ValueKey('plant-non-existent-toggle'));
    expect(toggleFinder, findsOneWidget);
    final switchWidget = tester.widget<SwitchListTile>(toggleFinder);
    expect(switchWidget.value, isTrue);

    // Can turn it back to false
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    final switchWidgetAfter = tester.widget<SwitchListTile>(toggleFinder);
    expect(switchWidgetAfter.value, isFalse);

    final updateButtonFinder = find.byKey(const ValueKey('plant-editor-update-button'));
    await tester.tap(updateButtonFinder);
    await tester.pumpAndSettle();

    expect(repo.setNonExistentCalls, 1);
  });
}

