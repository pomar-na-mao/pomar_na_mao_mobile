import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plant.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plants_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_view_model.dart';

class MockPlantsRepository implements PlantsRepository {
  @override
  Future<List<Plant>> fetchPlants() async => [];
}

class MockZonesRepository implements ZonesRepository {
  final Map<String, List<RegionPoint>> regionsByZone = {};

  @override
  Future<List<Zone>> fetchZones() async => [
    const Zone(id: 'zone-a', name: 'Zona A', code: 'A'),
    const Zone(id: 'zone-b', name: 'Zona B', code: 'B'),
  ];

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async {
    return regionsByZone[zoneId] ?? [];
  }
}

class MockFarmRepository implements FarmRepository {
  List<FarmPoint> boundaryPoints = const [];
  Exception? error;

  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async {
    final error = this.error;
    if (error != null) throw error;
    return boundaryPoints;
  }
}

class MockLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

void main() {
  group('RegionPoint.fromJson', () {
    test('instantiates with valid json', () {
      final json = {
        'latitude': -22.12145,
        'longitude': -48.95822,
        'region': 'A',
        'zone_id': 'zone-a',
      };

      final point = RegionPoint.fromJson(json);

      expect(point.latitude, -22.12145);
      expect(point.longitude, -48.95822);
      expect(point.region, 'A');
      expect(point.zoneId, 'zone-a');
    });
  });

  group('FarmPoint.fromJson', () {
    test('instantiates with valid json', () {
      final json = {
        'id': 1,
        'latitude': -22.12145,
        'longitude': -48.95822,
        'order': 7,
      };

      final point = FarmPoint.fromJson(json);

      expect(point.id, '1');
      expect(point.latitude, -22.12145);
      expect(point.longitude, -48.95822);
      expect(point.boundaryOrder, 7);
    });
  });

  group('FarmMapViewModel with zone polygons', () {
    test('loads and sets selectedZonePoints when zone is selected', () async {
      final plantsRepo = MockPlantsRepository();
      final zonesRepo = MockZonesRepository();
      final locationService = MockLocationService();
      final farmRepo = MockFarmRepository();

      zonesRepo.regionsByZone['zone-a'] = [
        const RegionPoint(
          latitude: -22.12,
          longitude: -48.95,
          zoneId: 'zone-a',
        ),
        const RegionPoint(
          latitude: -22.13,
          longitude: -48.96,
          zoneId: 'zone-a',
        ),
      ];

      final viewModel = FarmMapViewModel(
        plantsRepo,
        zonesRepo,
        locationService,
        farmRepo,
      );
      await viewModel.initialize();

      expect(viewModel.selectedZoneId, isNull);
      expect(viewModel.selectedZonePoints, isEmpty);

      viewModel.selectZone('zone-a');
      // Await microtasks / async loading
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(viewModel.selectedZoneId, 'zone-a');
      expect(viewModel.selectedZonePoints.length, 2);
      expect(viewModel.selectedZonePoints.first.latitude, -22.12);

      // Deselecting zone clears polygon points
      viewModel.selectZone(null);
      expect(viewModel.selectedZoneId, isNull);
      expect(viewModel.selectedZonePoints, isEmpty);
    });
  });

  group('FarmMapViewModel with farm boundary', () {
    test('loads farm boundary points during initialization', () async {
      final farmRepo = MockFarmRepository()
        ..boundaryPoints = const [
          FarmPoint(
            id: '1',
            latitude: -22.12,
            longitude: -48.95,
            boundaryOrder: 1,
          ),
          FarmPoint(
            id: '2',
            latitude: -22.13,
            longitude: -48.96,
            boundaryOrder: 2,
          ),
          FarmPoint(
            id: '3',
            latitude: -22.14,
            longitude: -48.94,
            boundaryOrder: 3,
          ),
        ];

      final viewModel = FarmMapViewModel(
        MockPlantsRepository(),
        MockZonesRepository(),
        MockLocationService(),
        farmRepo,
      );

      await viewModel.initialize();

      expect(viewModel.farmBoundaryPoints.length, 3);
      expect(viewModel.farmBoundaryPoints.first.id, '1');
    });

    test(
      'ignores farm boundary failure and keeps zone loading available',
      () async {
        final zonesRepo = MockZonesRepository();
        zonesRepo.regionsByZone['zone-a'] = [
          const RegionPoint(
            latitude: -22.12,
            longitude: -48.95,
            zoneId: 'zone-a',
          ),
          const RegionPoint(
            latitude: -22.13,
            longitude: -48.96,
            zoneId: 'zone-a',
          ),
          const RegionPoint(
            latitude: -22.14,
            longitude: -48.94,
            zoneId: 'zone-a',
          ),
        ];

        final viewModel = FarmMapViewModel(
          MockPlantsRepository(),
          zonesRepo,
          MockLocationService(),
          MockFarmRepository()..error = Exception('farm boundary failed'),
        );

        await viewModel.initialize();

        expect(viewModel.farmBoundaryPoints, isEmpty);
        expect(viewModel.zones, isNotEmpty);
        expect(viewModel.plantsStatus, PlantsLoadStatus.empty);

        viewModel.selectZone('zone-a');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(viewModel.selectedZonePoints.length, 3);
      },
    );
  });
}
