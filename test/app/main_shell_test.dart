import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/app/widgets/main_shell.dart';
import 'package:pomar_na_mao_mobile/core/ui/app_loading_controller.dart';
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
  testWidgets('shows the four destinations in order and selects each one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.label),
      ['Inventário', 'Fazenda', 'Operações', 'Sobre'],
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    for (final (label, index) in [
      ('Fazenda', 1),
      ('Operações', 2),
      ('Sobre', 3),
      ('Inventário', 0),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
    }

    expect(tester.takeException(), isNull);
  });

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

    expect(find.text('Fazenda Coatiara'), findsOneWidget);
    expect(find.text('21.809'), findsOneWidget);
    expect(inventoryRepository.calls, 1);

    await tester.tap(find.text('Operações'));
    await tester.pumpAndSettle();
    expect(find.text('Cuidado planta a planta'), findsOneWidget);

    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();
    expect(find.text('Quem somos'), findsOneWidget);

    await tester.tap(find.text('Inventário'));
    await tester.pumpAndSettle();
    expect(find.text('Fazenda Coatiara'), findsOneWidget);
    expect(inventoryRepository.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    farmViewModel.dispose();
  });

  testWidgets(
    'displays translucent loading overlay and blocks gestures when loading',
    (tester) async {
      final loadingController = AppLoadingController();
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: MainShell(loadingController: loadingController)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      final completer = Completer<void>();
      final trackedFuture = loadingController.track(() => completer.future);

      await tester.pump(); // rebuild with loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify background interactions are blocked while loading
      await tester.tap(find.text('Fazenda'), warnIfMissed: false);
      await tester.pump();

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      completer.complete();
      await trackedFuture;
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Interactions work after loading finishes
      await tester.tap(find.text('Fazenda'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
  );
}
