import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/app/widgets/main_shell.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plant.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plants_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_view_model.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/inventory/domain/inventory_summary.dart';
import 'package:pomar_na_mao_mobile/features/inventory/presentation/inventory_view_model.dart';

class ShellInventoryRepository implements InventoryRepository {
  int calls = 0;

  @override
  Future<InventorySummary> fetchSummary() async {
    calls += 1;
    return const InventorySummary(
      existingPlants: 21809,
      availablePlantingSpots: 2,
    );
  }
}

class ShellPlantsRepository implements PlantsRepository {
  @override
  Future<List<Plant>> fetchPlants() async => const [];
}

class ShellFarmRepository implements FarmRepository {
  @override
  Future<List<FarmPoint>> fetchFarmBoundary() =>
      Future.error(Exception('map intentionally unavailable in shell test'));
}

class ShellZonesRepository implements ZonesRepository {
  @override
  Future<List<Zone>> fetchZones() =>
      Future.error(Exception('map intentionally unavailable in shell test'));

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async =>
      const [];
}

class ShellLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

void main() {
  testWidgets('opens inventory first and preserves it across navigation', (
    tester,
  ) async {
    final inventoryRepository = ShellInventoryRepository();
    final farmRepository = ShellFarmRepository();
    final zonesRepository = ShellZonesRepository();
    final inventoryViewModel = InventoryViewModel(
      inventoryRepository,
      farmRepository,
      zonesRepository,
    );
    final farmViewModel = FarmMapViewModel(
      ShellPlantsRepository(),
      zonesRepository,
      ShellLocationService(),
      farmRepository,
    );
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          farmMapViewModel: farmViewModel,
          inventoryViewModel: inventoryViewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sítio São Francisco'), findsOneWidget);
    expect(find.text('21.809'), findsOneWidget);
    expect(inventoryRepository.calls, 1);

    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();
    expect(find.text('Quem somos'), findsOneWidget);

    await tester.tap(find.text('Inventário'));
    await tester.pumpAndSettle();
    expect(find.text('Sítio São Francisco'), findsOneWidget);
    expect(inventoryRepository.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    farmViewModel.dispose();
  });
}
