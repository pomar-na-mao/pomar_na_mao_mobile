import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/activity_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/activity_view_model.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/activity_entry_modal.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/activity_saved_entries.dart';

void main() {
  testWidgets('map builder receives state and drawing callbacks at 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = ActivityViewModel(
      repository: _Repository(),
      locationService: _NoLocationService(),
    );
    addTearDown(viewModel.dispose);
    ActivityMapConfig? config;
    var mapPanUpdates = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityView(
          viewModel: viewModel,
          mapBuilder: (_, value) {
            config = value;
            return GestureDetector(
              key: ValueKey('activity-fake-map'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (_) => mapPanUpdates++,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-fake-map')), findsOneWidget);
    expect(config, isNotNull);
    expect(config!.plants, isEmpty);
    expect(find.text('Mover mapa'), findsNothing);
    expect(find.byKey(const ValueKey('activity-drawing-mode')), findsNothing);
    expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    final loadButton = tester.getRect(
      find.byKey(const ValueKey('activity-load-data')),
    );
    final drawButton = tester.getRect(
      find.byKey(const ValueKey('activity-open-drawing')),
    );
    final filterButton = tester.getRect(
      find.byKey(const ValueKey('activity-filter-zone')),
    );
    final savedButton = tester.getRect(
      find.byKey(const ValueKey('activity-saved-entries')),
    );
    expect(loadButton.width, filterButton.width);
    expect(filterButton.width, drawButton.width);
    expect(drawButton.width, savedButton.width);
    expect(loadButton.width, greaterThan(50));
    expect(filterButton.left - loadButton.right, 10);
    expect(drawButton.left - filterButton.right, 10);
    expect(savedButton.left - drawButton.right, 10);

    await tester.tap(find.byKey(const ValueKey('activity-open-drawing')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('activity-drawing-modal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-drawing-modal-top-margin')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('activity-drawing-modal')))
          .dy,
      greaterThanOrEqualTo(104),
    );
    final geometrySelector = tester
        .widget<SegmentedButton<ActivityGeometryType>>(
          find.byKey(const ValueKey('activity-geometry-selector')),
        );
    expect(
      geometrySelector.style?.backgroundColor?.resolve({WidgetState.selected}),
      const Color(0xFF166534),
    );
    expect(
      geometrySelector.style?.foregroundColor?.resolve({WidgetState.selected}),
      Colors.white,
    );
    final modalMap = tester.getRect(
      find.byKey(const ValueKey('activity-fake-map')),
    );
    await tester.dragFrom(
      Offset(modalMap.center.dx, modalMap.bottom - 48),
      const Offset(0, -80),
    );
    await tester.pump();
    expect(mapPanUpdates, greaterThan(0));
    expect(find.text('Desenhar operação'), findsOneWidget);
    expect(find.text('Mover mapa'), findsOneWidget);
    expect(find.text('Desenhando'), findsNothing);
    final actionCenters = [
      'activity-drawing-mode',
      'activity-drawing-undo',
      'activity-drawing-clear',
      'activity-drawing-continue',
    ].map((key) => tester.getCenter(find.byKey(ValueKey(key))).dy).toList();
    expect(actionCenters.toSet(), hasLength(1));
    const userCamera = CameraPosition(
      target: LatLng(-22.123, -48.456),
      zoom: 17.5,
    );
    config!.onCameraMove!(userCamera);
    config!.onAddPoint(const ActivityPoint(-21, -47));
    await tester.pump();
    expect(config!.initialCameraPosition, userCamera);
    await tester.tap(find.byKey(const ValueKey('activity-drawing-mode')));
    await tester.pump();
    expect(find.text('Desenhando'), findsOneWidget);
    config!.onAddPoint(const ActivityPoint(-21.01, -47.01));
    await tester.pump();
    expect(config!.points, hasLength(2));
    expect(find.text('Continuar (2)'), findsOneWidget);

    await tester.tap(find.text('Área'));
    await tester.pumpAndSettle();
    expect(find.text('Trocar tipo de desenho?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(config!.geometryType, ActivityGeometryType.route);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters plants and opens drawing centered on the zone', (
    tester,
  ) async {
    final repository = _Repository(
      plants: [
        InspectionPlant(
          id: 'plant-a',
          latitude: -21,
          longitude: -47,
          zoneId: 'zone-a',
        ),
        InspectionPlant(
          id: 'plant-b',
          latitude: -22,
          longitude: -48,
          zoneId: 'zone-b',
        ),
      ],
    );
    final viewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
      zonesRepository: _ZonesRepository(),
    );
    addTearDown(viewModel.dispose);
    ActivityMapConfig? config;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityView(
          viewModel: viewModel,
          mapBuilder: (_, value) {
            config = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config!.plants, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('activity-filter-zone')));
    await tester.pumpAndSettle();
    expect(find.text('Filtros de Plantas'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('activity-filter-zone-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zona A').last);
    await tester.pumpAndSettle();

    expect(config!.plants.single.id, 'plant-a');
    expect(config!.selectedZoneId, 'zone-a');
    expect(config!.selectedZonePoints, hasLength(4));
    await tester.tap(
      find.byKey(const ValueKey('activity-apply-zone-filter-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('activity-zone-filter-badge')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('activity-open-drawing')));
    await tester.pumpAndSettle();
    expect(
      config!.initialCameraPosition.target.latitude,
      closeTo(-21.05, 1e-9),
    );
    expect(
      config!.initialCameraPosition.target.longitude,
      closeTo(-47.05, 1e-9),
    );
    expect(config!.selectedZoneId, 'zone-a');
    expect(config!.selectedZonePoints, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal selects a read-only mixture and saves its snapshots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final viewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
    );
    addTearDown(viewModel.dispose);
    await viewModel.loadSnapshot();
    viewModel.addPoint(const ActivityPoint(-21, -47));
    viewModel.addPoint(const ActivityPoint(-21.01, -47.01));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => ActivityEntryModal.show(context, viewModel),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-entry-modal-top-margin')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byType(ActivityEntryModal)).dy,
      greaterThanOrEqualTo(224),
    );
    final dateTop = tester.getTopLeft(
      find.byKey(const ValueKey('activity-date')),
    );
    final timeTop = tester.getTopLeft(
      find.byKey(const ValueKey('activity-time')),
    );
    expect(dateTop.dy, timeTop.dy);

    await tester.enterText(
      find.byKey(const ValueKey('activity-activity')),
      'roçagem',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('activity-responsible')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-responsible')),
      'João',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('activity-select-machine')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('activity-select-machine')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar Máquina/Trator'), findsOneWidget);
    expect(find.text('Trator Valtra A950'), findsOneWidget);
    expect(find.text('Valtra • Ano 2024'), findsOneWidget);
    await tester.tap(find.text('Trator Valtra A950'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('activity-select-mixture')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('activity-select-mixture')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar calda'), findsOneWidget);
    expect(find.text('Escolha uma receita cadastrada'), findsOneWidget);
    expect(find.text('Calda cítrica'), findsOneWidget);
    expect(find.text('1 insumo'), findsOneWidget);
    await tester.tap(find.text('Calda cítrica'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(find.text('Produto — 75 mL/100L\nIngrediente'), findsOneWidget);
    expect(
      find.text(
        'Somente leitura. Nome, observações, insumos, doses e unidades da '
        'calda não podem ser alterados.',
      ),
      findsOneWidget,
    );
    final mixtureCard = find.ancestor(
      of: find.text('Produto — 75 mL/100L\nIngrediente'),
      matching: find.byType(Card),
    );
    expect(mixtureCard, findsOneWidget);
    expect(
      find.descendant(of: mixtureCard, matching: find.byType(TextFormField)),
      findsNothing,
    );
    expect(find.text('Dose aplicada'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('activity-save')));
    await tester.tap(find.byKey(const ValueKey('activity-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.activity, 'roçagem');
    expect(repository.saved!.responsible, 'João');
    expect(repository.saved!.machineId, 'machine-1');
    expect(repository.saved!.machineNameSnapshot, 'Trator Valtra A950');
    expect(repository.saved!.machineBrandSnapshot, 'Valtra');
    expect(repository.saved!.mixtureId, 'mixture-1');
    expect(repository.saved!.mixtureNameSnapshot, 'Calda cítrica');
    expect(repository.saved!.inputs.single.nameSnapshot, 'Produto');
    expect(repository.saved!.inputs.single.appliedDose, '75');
    expect(find.byType(ActivityEntryModal), findsNothing);
  });

  testWidgets('required fields keep modal open and show messages', (
    tester,
  ) async {
    final repository = _Repository();
    final viewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
    );
    addTearDown(viewModel.dispose);
    viewModel.addPoint(const ActivityPoint(-21, -47));
    viewModel.addPoint(const ActivityPoint(-21.01, -47.01));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ActivityEntryModal.show(context, viewModel),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-save')));
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    expect(find.byType(ActivityEntryModal), findsOneWidget);
    expect(repository.saved, isNull);
  });

  testWidgets('saved list shows summary, error and sync actions', (
    tester,
  ) async {
    final repository = _Repository()
      ..saved = ActivityEntry(
        localId: 'entry-error',
        geometry: ActivityGeometry(
          type: ActivityGeometryType.route,
          points: const [
            ActivityPoint(-21, -47),
            ActivityPoint(-21.01, -47.01),
          ],
        ),
        activity: 'roçagem',
        performedAt: DateTime(2026, 10, 30, 12, 30),
        responsible: 'João',
        inputs: const [],
        syncStatus: ActivitySyncStatus.error,
        error: 'Sem conexão',
      );
    final viewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ActivitySavedEntries.show(context, viewModel),
              child: const Text('Salvos'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salvos'));
    await tester.pumpAndSettle();

    expect(find.text('Operações salvas'), findsOneWidget);
    expect(find.text('1 registro no dispositivo'), findsOneWidget);
    expect(find.text('roçagem'), findsOneWidget);
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.text('Erro'), findsOneWidget);
    expect(find.textContaining('Rota: 2 pontos'), findsOneWidget);
    expect(find.textContaining('0 insumos'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sincronizar'));
    await tester.pumpAndSettle();
    expect(repository.syncOneCalls, 1);

    final deleteButton = find.byKey(
      const ValueKey('activity-delete-entry-error'),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Excluir operação?'), findsOneWidget);
    expect(find.textContaining('somente a cópia salva'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('roçagem'), findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(find.text('roçagem'), findsNothing);
    expect(find.text('Nenhuma operação salva no dispositivo.'), findsOneWidget);

    repository.saved = ActivityEntry(
      localId: 'entry-synced',
      geometry: ActivityGeometry(
        type: ActivityGeometryType.route,
        points: const [ActivityPoint(-21, -47), ActivityPoint(-21.01, -47.01)],
      ),
      activity: 'operação sincronizada',
      performedAt: DateTime(2026, 10, 30, 12, 30),
      responsible: 'João',
      inputs: const [],
      syncStatus: ActivitySyncStatus.synced,
    );
    await viewModel.loadEntries();
    await tester.pump();
    final syncedDeleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('activity-delete-entry-synced')),
    );
    expect(syncedDeleteButton.onPressed, isNull);
  });

  testWidgets('updates GPS without showing a stabilization overlay', (
    tester,
  ) async {
    final locationService = _ControlledLocationService();
    ActivityMapConfig? config;
    addTearDown(locationService.dispose);
    final viewModel = ActivityViewModel(
      repository: _Repository(),
      locationService: locationService,
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityView(
          viewModel: viewModel,
          mapBuilder: (_, value) {
            config = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('spraying-signal-message')), findsNothing);

    final now = DateTime.now().toUtc();
    for (var secondsAgo = 2; secondsAgo >= 0; secondsAgo--) {
      locationService.add(
        LocationResult.available(
          UserLocation(
            latitude: -21,
            longitude: -47,
            accuracy: 3,
            timestamp: now.subtract(Duration(seconds: secondsAgo)),
          ),
        ),
      );
      await tester.pump();
    }

    expect(viewModel.userLocation, isNotNull);
    expect(find.byKey(const ValueKey('spraying-signal-message')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('activity-open-drawing')));
    await tester.pumpAndSettle();
    const userCamera = CameraPosition(
      target: LatLng(-22.345, -48.678),
      zoom: 18,
    );
    final previousLocationTimestamp = config!.userLocation!.timestamp!;
    config!.onCameraMove!(userCamera);
    final modalNow = DateTime.now().toUtc();
    for (var step = 0; step < 3; step++) {
      locationService.add(
        LocationResult.available(
          UserLocation(
            latitude: -21 - ((step + 1) * 0.00004),
            longitude: -47,
            accuracy: 3,
            timestamp: modalNow.add(Duration(seconds: step)),
          ),
        ),
      );
      await tester.pump();
    }

    expect(config!.userLocation!.timestamp, isNot(previousLocationTimestamp));
    expect(config!.initialCameraPosition, userCamera);
  });
}

class _Repository implements ActivityRepository {
  _Repository({this.plants = const []});

  final List<InspectionPlant> plants;
  ActivityEntry? saved;
  var sequence = 0;
  var syncOneCalls = 0;
  var deleteCalls = 0;

  @override
  String createLocalId() => 'local-${sequence++}';

  @override
  Future<ActivitySnapshot> loadSnapshot({bool forceRemote = false}) async =>
      ActivitySnapshot(
        plants: plants,
        mixtures: [
          MixtureCatalogItem(
            id: 'mixture-1',
            name: 'Calda cítrica',
            isActive: true,
            inputs: const [
              MixtureInputCatalogItem(
                inputId: 'input-1',
                name: 'Produto',
                dose: '75',
                doseUnit: 'mL/100L',
                activeIngredient: 'Ingrediente',
              ),
            ],
          ),
        ],
        machines: [
          MachineCatalogItem(
            id: 'machine-1',
            name: 'Trator Valtra A950',
            brand: 'Valtra',
            manufacturingYear: 2024,
          ),
        ],
      );

  @override
  Future<List<ActivityEntry>> list() async => [?saved];

  @override
  Future<bool> deleteLocal(String localId) async {
    deleteCalls++;
    if (saved?.localId != localId) return false;
    saved = null;
    return true;
  }

  @override
  Future<ActivityEntry> save({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    List<ActivityInput> inputs = const [],
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
  }) async => saved = ActivityEntry(
    localId: createLocalId(),
    geometry: geometry,
    activity: activity,
    performedAt: performedAt,
    responsible: responsible,
    mixtureId: mixture?.id,
    mixtureNameSnapshot: mixture?.name,
    machineId: machine?.id,
    machineNameSnapshot: machine?.name,
    machineBrandSnapshot: machine?.brand,
    inputs: mixture == null
        ? inputs
        : mixture.inputs
              .map(
                (item) => ActivityInput(
                  localId: createLocalId(),
                  inputId: item.inputId,
                  nameSnapshot: item.name,
                  activeIngredientSnapshot: item.activeIngredient,
                  labelDoseSnapshot: item.labelDose,
                  doseUnitSnapshot: item.doseUnit,
                  appliedDose: item.dose,
                ),
              )
              .toList(),
  );

  @override
  Future<bool> syncAll() async => true;

  @override
  Future<bool> syncOne(String localId) async {
    syncOneCalls++;
    return true;
  }
}

class _ZonesRepository implements ZonesRepository {
  @override
  Future<List<Zone>> fetchZones() async => const [
    Zone(id: 'zone-a', name: 'Zona A'),
    Zone(id: 'zone-b', name: 'Zona B'),
  ];

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async => const [
    RegionPoint(latitude: -21.0, longitude: -47.0, zoneId: 'zone-a'),
    RegionPoint(latitude: -21.0, longitude: -47.1, zoneId: 'zone-a'),
    RegionPoint(latitude: -21.1, longitude: -47.1, zoneId: 'zone-a'),
    RegionPoint(latitude: -21.1, longitude: -47.0, zoneId: 'zone-a'),
  ];
}

class _NoLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

class _ControlledLocationService implements LocationService {
  final _controller = StreamController<LocationResult>.broadcast();

  void add(LocationResult result) => _controller.add(result);

  void dispose() => _controller.close();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => _controller.stream;
}
