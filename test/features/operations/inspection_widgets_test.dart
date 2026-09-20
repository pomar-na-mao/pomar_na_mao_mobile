import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  int finalizeCalls = 0;
  int syncCalls = 0;

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
  Future<List<LocalInspection>> listLocalInspections() async => inspections;

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
        'action-saved-inspections',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    }
    await tester.binding.setSurfaceSize(null);
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
}
