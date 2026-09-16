import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/di/app_dependencies.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plant.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plants_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';

class MockFarmRepository implements FarmRepository {
  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async => const [];
}

class MockPlantsRepository implements PlantsRepository {
  @override
  Future<List<Plant>> fetchPlants() async => const [];
}

class MockZonesRepository implements ZonesRepository {
  @override
  Future<List<Zone>> fetchZones() async => const [];

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async => const [];
}

class MockInventoryRepository implements InventoryRepository {
  @override
  Future<InventorySummary> fetchSummary() async => const InventorySummary(
        existingPlants: 10,
        availablePlantingSpots: 5,
      );
}

class MockLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

void main() {
  group('AppDependencies', () {
    test('initializes and provides view models and repositories cleanly', () {
      final dependencies = AppDependencies(
        farmRepository: MockFarmRepository(),
        plantsRepository: MockPlantsRepository(),
        zonesRepository: MockZonesRepository(),
        inventoryRepository: MockInventoryRepository(),
        locationService: MockLocationService(),
      );

      expect(dependencies.inventoryViewModel, isNotNull);
      expect(dependencies.farmMapViewModel, isNotNull);

      expect(() => dependencies.dispose(), returnsNormally);
    });
  });
}
