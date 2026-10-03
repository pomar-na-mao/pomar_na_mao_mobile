import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plant.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plants_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_view.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_view_model.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/widgets/farm_action_card.dart';

Plant _createPlant({
  required String id,
  required String zoneId,
  required double latitude,
  required double longitude,
}) {
  return Plant(
    id: id,
    zoneId: zoneId,
    latitude: latitude,
    longitude: longitude,
    isDead: false,
    isNew: false,
    nonExistent: false,
    syncStatus: 'synced',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

class _FakePlantsRepository implements PlantsRepository {
  List<Plant> plants = [
    _createPlant(id: 'plant-1', zoneId: 'zone-a', latitude: -23.0, longitude: -47.0),
    _createPlant(id: 'plant-2', zoneId: 'zone-b', latitude: -23.1, longitude: -47.1),
  ];

  @override
  Future<List<Plant>> fetchPlants() async => plants;
}

class _FakeZonesRepository implements ZonesRepository {
  List<Zone> zones = const [
    Zone(id: 'zone-a', name: 'Zona Alfa', code: 'A'),
    Zone(id: 'zone-b', name: 'Zona Beta', code: 'B'),
  ];

  @override
  Future<List<Zone>> fetchZones() async => zones;

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async => const [];
}

class _FakeFarmRepository implements FarmRepository {
  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async => const [];
}

class _FakeLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

void main() {
  test('sorts zones alphabetically by code without changing the source', () {
    const zones = [
      Zone(id: 'zone-c', name: 'Terceira', code: 'C'),
      Zone(id: 'zone-no-code', name: 'Sem código'),
      Zone(id: 'zone-b', name: 'Segunda', code: ' b '),
      Zone(id: 'zone-a', name: 'Primeira', code: 'A'),
    ];

    final sortedZones = sortZonesByCode(zones);

    expect(sortedZones.map((zone) => zone.id), [
      'zone-a',
      'zone-b',
      'zone-c',
      'zone-no-code',
    ]);
    expect(zones.first.id, 'zone-c');
  });

  testWidgets('FarmActionCard renders below map and opens FarmZoneFilterModal', (
    tester,
  ) async {
    final plantsRepo = _FakePlantsRepository();
    final zonesRepo = _FakeZonesRepository();
    final farmRepo = _FakeFarmRepository();
    final locationService = _FakeLocationService();
    final vm = FarmMapViewModel(plantsRepo, zonesRepo, locationService, farmRepo);

    await vm.loadFarmData();

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FarmMapView(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    // Verify FarmActionCard is displayed
    expect(find.byType(FarmActionCard), findsOneWidget);
    expect(find.byKey(const ValueKey('action-farm-load-plants')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-farm-filter-zone')), findsOneWidget);

    // Tap on filter button
    await tester.tap(find.byKey(const ValueKey('action-farm-filter-zone')));
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.text('Filtros de Plantas'), findsOneWidget);
    expect(find.text('2 de 2 plantas visíveis'), findsOneWidget);
    expect(find.byKey(const ValueKey('farm-filter-zone-dropdown')), findsOneWidget);

    // Tap on "Ver no mapa"
    await tester.tap(find.byKey(const ValueKey('apply-farm-zone-filter-button')));
    await tester.pumpAndSettle();

    // Modal closed
    expect(find.text('Filtros de Plantas'), findsNothing);

    // Filter by zone directly on vm
    vm.selectZone('zone-a');
    await tester.pumpAndSettle();

    // Check active zone badge appears on map
    expect(find.byKey(const ValueKey('clear-farm-zone-badge-button')), findsOneWidget);
    expect(find.text('Zona Alfa'), findsOneWidget);

    // Tap close on badge to clear filter
    await tester.tap(find.byKey(const ValueKey('clear-farm-zone-badge-button')));
    await tester.pumpAndSettle();

    expect(vm.selectedZoneId, isNull);
    expect(find.byKey(const ValueKey('clear-farm-zone-badge-button')), findsNothing);
  });
}
