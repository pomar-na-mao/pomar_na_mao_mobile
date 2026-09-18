import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';
import 'package:pomar_na_mao_mobile/features/inventory/presentation/inventory_map.dart';
import 'package:pomar_na_mao_mobile/features/inventory/presentation/inventory_view.dart';
import 'package:pomar_na_mao_mobile/features/inventory/presentation/inventory_view_model.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_geometry.dart';

class ViewTestInventoryRepository implements InventoryRepository {
  InventorySummary result = const InventorySummary(
    existingPlants: 21809,
    availablePlantingSpots: 2,
  );
  Exception? error;

  @override
  Future<InventorySummary> fetchSummary() async {
    if (error case final error?) throw error;
    return result;
  }
}

class ViewTestFarmRepository implements FarmRepository {
  Exception? error;
  List<FarmPoint> result = const [
    FarmPoint(id: '1', latitude: -22.1, longitude: -48.9, boundaryOrder: 1),
    FarmPoint(id: '2', latitude: -22.2, longitude: -48.9, boundaryOrder: 2),
    FarmPoint(id: '3', latitude: -22.1, longitude: -48.8, boundaryOrder: 3),
  ];

  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async {
    if (error case final error?) throw error;
    return result;
  }
}

class ViewTestZonesRepository implements ZonesRepository {
  Exception? error;
  List<Zone> zones = const [Zone(id: 'zone-a', name: 'Zona A', code: 'A')];
  List<RegionPoint> regions = const [
    RegionPoint(latitude: -22.12, longitude: -48.88, zoneId: 'zone-a'),
    RegionPoint(latitude: -22.16, longitude: -48.90, zoneId: 'zone-a'),
    RegionPoint(latitude: -22.14, longitude: -48.84, zoneId: 'zone-a'),
  ];

  @override
  Future<List<Zone>> fetchZones() async {
    if (error case final error?) throw error;
    return zones;
  }

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async {
    if (error case final error?) throw error;
    return regions;
  }
}

InventoryViewModel buildViewModel({
  ViewTestInventoryRepository? inventoryRepository,
  ViewTestFarmRepository? farmRepository,
  ViewTestZonesRepository? zonesRepository,
}) {
  return InventoryViewModel(
    inventoryRepository ?? ViewTestInventoryRepository(),
    farmRepository ?? ViewTestFarmRepository(),
    zonesRepository ?? ViewTestZonesRepository(),
  );
}

Widget buildSubject(
  InventoryViewModel viewModel, {
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  String fruitAssetPath = 'assets/images/fruit.png',
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
      platform: platform,
      useMaterial3: true,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: InventoryView(
      viewModel: viewModel,
      fruitAssetPath: fruitAssetPath,
      mapBuilder: (context, farmPoints, zonePointsById) {
        final zonePointCount = zonePointsById.values.fold<int>(
          0,
          (total, points) => total + points.length,
        );
        return ColoredBox(
          key: const ValueKey('test-map'),
          color: Colors.lightGreen.shade50,
          child: Center(
            child: Text(
              '${farmPoints.length}/$zonePointCount/${zonePointsById.length}',
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  test('formats inventory totals for pt-BR readability', () {
    expect(formatInventoryCount(0), '0');
    expect(formatInventoryCount(999), '999');
    expect(formatInventoryCount(1000), '1.000');
    expect(formatInventoryCount(21809), '21.809');
  });

  test('configures the inventory map without plants or location', () {
    const farmPoints = [
      FarmPoint(id: '1', latitude: -22.1, longitude: -48.9, boundaryOrder: 1),
      FarmPoint(id: '2', latitude: -22.2, longitude: -48.9, boundaryOrder: 2),
      FarmPoint(id: '3', latitude: -22.1, longitude: -48.8, boundaryOrder: 3),
    ];
    const zonePoints = [
      RegionPoint(
        latitude: -22.12,
        longitude: -48.88,
        region: 'A',
        zoneId: 'zone-a',
      ),
      RegionPoint(
        latitude: -22.16,
        longitude: -48.90,
        region: 'A',
        zoneId: 'zone-a',
      ),
      RegionPoint(
        latitude: -22.14,
        longitude: -48.84,
        region: 'A',
        zoneId: 'zone-a',
      ),
    ];
    final coordinates = [
      ...farmPoints.map((point) => LatLng(point.latitude, point.longitude)),
      ...zonePoints.map((point) => LatLng(point.latitude, point.longitude)),
    ];

    final map = createInventoryGoogleMap(
      farmPoints: farmPoints,
      zonePointsById: const {'zone-a': zonePoints},
      zoneLabelIcons: const {'A': BitmapDescriptor.defaultMarker},
      viewport: calculateMapCameraViewport(coordinates),
      onMapCreated: (_) {},
    );

    expect(map.polygons, hasLength(2));
    final zonePolygon = map.polygons.singleWhere(
      (polygon) => polygon.polygonId == const PolygonId('zone_zone-a'),
    );
    expect(zonePolygon.strokeColor, Colors.transparent);
    expect(zonePolygon.strokeWidth, 0);
    expect(map.polylines, hasLength(1));
    expect(
      map.polylines.single.polylineId,
      const PolylineId('zone_dotted_zone-a'),
    );
    expect(map.markers, hasLength(1));
    expect(map.markers.single.markerId, const MarkerId('zone_label_zone-a'));
    expect(map.markers.single.infoWindow.title, 'Zona A');
    expect(map.clusterManagers, isEmpty);
    expect(map.myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
  });

  test('places each zone letter at the center of its polygon', () {
    const zoneBPoints = [
      RegionPoint(latitude: -22.10, longitude: -48.90, region: 'Zona B'),
      RegionPoint(latitude: -22.20, longitude: -48.80, region: 'B'),
      RegionPoint(latitude: -22.15, longitude: -48.85, region: 'B'),
    ];

    final markers = buildZoneLabelMarkers(
      zonePointsById: const {'zone-b': zoneBPoints},
      iconsByLabel: const {'B': BitmapDescriptor.defaultMarker},
    );

    expect(markers, hasLength(1));
    final marker = markers.single;
    expect(marker.infoWindow.title, 'Zona B');
    expect(marker.anchor, const Offset(0.5, 0.5));
    expect(marker.position.latitude, closeTo(-22.15, 0.000001));
    expect(marker.position.longitude, closeTo(-48.85, 0.000001));
  });

  testWidgets('renders all dashboard blocks in semantic order', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSubject(buildViewModel()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inventory-property-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inventory-summary-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inventory-cultivation-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inventory-map-card')), findsOneWidget);
    expect(find.text('Sítio São Francisco'), findsOneWidget);
    expect(find.text('54 ha'), findsOneWidget);
    expect(find.text('Avocado'), findsOneWidget);
    expect(find.bySemanticsLabel('Ilustração de avocado'), findsOneWidget);
    expect(find.text('21.809'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('8 × 5 m'), findsOneWidget);
    expect(find.text('Semi-adensado'), findsOneWidget);
    expect(find.text('250 plantas/ha'), findsOneWidget);
    expect(find.text('Hass'), findsOneWidget);
    expect(find.text('Fazenda'), findsOneWidget);
    expect(find.text('Zonas A–G'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Zonas A–G, limite pontilhado verde'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);
    expect(find.text('3/3/1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('keeps layout stable when the fruit asset is unavailable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(
        buildViewModel(),
        fruitAssetPath: 'assets/images/missing-fruit.png',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Sítio São Francisco'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows summary error and retries only the totals', (
    tester,
  ) async {
    final inventoryRepository = ViewTestInventoryRepository()
      ..error = Exception('failed');
    final farmRepository = ViewTestFarmRepository();
    final viewModel = buildViewModel(
      inventoryRepository: inventoryRepository,
      farmRepository: farmRepository,
    );
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSubject(viewModel));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os totais de plantas.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);

    inventoryRepository.error = null;
    final retry = find.descendant(
      of: find.byKey(const ValueKey('inventory-summary-section')),
      matching: find.text('Tentar novamente'),
    );
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('21.809'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps totals visible during partial map failure', (
    tester,
  ) async {
    final farmRepository = ViewTestFarmRepository()
      ..error = Exception('farm failed');
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(buildViewModel(farmRepository: farmRepository)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('inventory-map-card')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('21.809'), findsOneWidget);
    expect(
      find.text('O limite da fazenda não pôde ser exibido.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a single map retry and recovers from total map failure', (
    tester,
  ) async {
    final farmRepository = ViewTestFarmRepository()
      ..error = Exception('farm failed');
    final zonesRepository = ViewTestZonesRepository()
      ..error = Exception('zones failed');
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(
        buildViewModel(
          farmRepository: farmRepository,
          zonesRepository: zonesRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('inventory-map-card')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final mapCard = find.byKey(const ValueKey('inventory-map-card'));
    final retry = find.descendant(
      of: mapCard,
      matching: find.text('Tentar novamente'),
    );
    expect(retry, findsOneWidget);
    expect(find.text('21.809'), findsOneWidget);

    farmRepository.error = null;
    zonesRepository.error = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the fallback map and notice without polygon coordinates', (
    tester,
  ) async {
    final farmRepository = ViewTestFarmRepository()..result = const [];
    final zonesRepository = ViewTestZonesRepository()..regions = const [];
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(
        buildViewModel(
          farmRepository: farmRepository,
          zonesRepository: zonesRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('inventory-map-card')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Os limites da propriedade estão indisponíveis.'),
      findsOneWidget,
    );
    expect(find.text('0/0/1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'is responsive at 320 px with enlarged text on ${platform.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(buildViewModel(), platform: platform, textScale: 1.6),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('inventory-map-card')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('inventory-map-card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('uses the wide layout without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSubject(buildViewModel()));
    await tester.pumpAndSettle();

    expect(find.text('21.809'), findsOneWidget);
    expect(find.byKey(const ValueKey('test-map')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
