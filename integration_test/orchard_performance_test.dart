import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/core/diagnostics/runtime_diagnostics.dart';
import 'package:pomar_na_mao_mobile/app/pomar_na_mao_app.dart';
import 'package:pomar_na_mao_mobile/core/data/shared_read_repository.dart';
import 'package:pomar_na_mao_mobile/core/di/app_dependencies.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/datasources/farm_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/supabase_farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/supabase_plants_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/supabase_zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/inventory/data/supabase_inventory_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';

import '../test/support/orchard_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const count = int.fromEnvironment('PLANT_COUNT', defaultValue: 21000);
  const cycles = int.fromEnvironment('NAVIGATION_CYCLES', defaultValue: 50);

  testWidgets('synthetic orchard $count navigation baseline', (tester) async {
    final database = InspectionDatabase(
      projectUrl: 'https://benchmark-$count.invalid',
    );
    final store = InspectionLocalStore(database);
    final fixture = OrchardFixture(count);
    await tester.runAsync(() async {
      if (!await store.hasCompleteCache(InspectionLocalStore.plantsCacheKey)) {
        await fixture.seed(store);
      }
      await store.replaceFarmRows(const []);
      for (final zone in fixture.zones) {
        await store.replaceRegionRows(zone['id'] as String, const []);
      }
    });
    final shared = SharedReadRepository(
      localStore: store,
      farmRemoteDataSource: _OfflineFarm(),
      inspectionRemoteDataSource: FakeEmptyRemoteDataSource(),
    );
    final dependencies = AppDependencies(
      farmRepository: SupabaseFarmRepository.fromShared(shared),
      plantsRepository: SupabasePlantsRepository.fromShared(shared),
      zonesRepository: SupabaseZonesRepository.fromShared(shared),
      inventoryRepository: SupabaseInventoryRepository.fromShared(shared),
      locationService: _NoLocation(),
      inspectionDatabase: database,
      sharedReadRepository: shared,
      inspectionRepository: DefaultInspectionRepository(
        localStore: store,
        remoteDataSource: FakeEmptyRemoteDataSource(),
        sharedReadRepository: shared,
      ),
    );
    final startup = Stopwatch()..start();
    await tester.pumpWidget(PomarNaMaoApp(dependencies: dependencies));
    for (
      var i = 0;
      i < 150 && find.byType(NavigationBar).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(NavigationBar), findsOneWidget);
    final shellMs = startup.elapsedMilliseconds;
    final samples = <int>[];
    var inspectionOpened = false;
    await binding.watchPerformance(() async {
      for (var i = 0; i < cycles; i++) {
        final index = i % 3;
        final watch = Stopwatch()..start();
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pump();
        samples.add(watch.elapsedMilliseconds);
        await tester.pump(const Duration(seconds: 1));
        if (index == 2 && !inspectionOpened) {
          await tester.tap(
            find.byKey(const ValueKey('operation-card-inspection')),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 3));
          inspectionOpened = true;
        }
        await _pumpUntilMapProjectionSettles(
          tester,
          shouldHaveMarkers: count > 0 && (index == 1 || index == 2),
        );
        expect(
          find.byType(GoogleMap, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(1),
        );
        for (final map in tester.widgetList<GoogleMap>(
          find.byType(GoogleMap),
        )) {
          expect(map.markers.length, lessThanOrEqualTo(1000));
          if (count > 0 && index == 1) {
            expect(dependencies.farmMapViewModel.allPlants, isNotEmpty);
            expect(
              map.markers,
              isNotEmpty,
              reason: 'Farm must show the loaded orchard',
            );
          }
          if (count > 0 && index == 2) {
            expect(dependencies.inspectionViewModel.allPlants, isNotEmpty);
            expect(
              map.markers,
              isNotEmpty,
              reason: 'Inspection must show the loaded orchard',
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
    }, reportKey: 'navigation');
    binding.reportData!['orchard'] = {
      'plants': count,
      'shellMs': shellMs,
      'navigationMs': samples,
      'diagnostics': jsonDecode(RuntimeDiagnostics.instance.exportJson()),
      'dataSource': 'synthetic local cache; no production HTTP',
      'limitations': 'Warm process UI test including Inspection. Not full acceptance matrix.',
    };
    // Captured by the host runner alongside native Android diagnostics.
    debugPrint('ORCHARD_BENCHMARK ${jsonEncode(binding.reportData)}');
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}

Future<void> _pumpUntilMapProjectionSettles(
  WidgetTester tester, {
  required bool shouldHaveMarkers,
}) async {
  for (var i = 0; i < 25; i++) {
    final maps = tester.widgetList<GoogleMap>(find.byType(GoogleMap));
    if (!shouldHaveMarkers || maps.any((map) => map.markers.isNotEmpty)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.permissionDenied();
  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

class _OfflineFarm implements FarmRemoteDataSource {
  Never _unexpected() =>
      throw StateError('Unexpected remote read in warm benchmark');
  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({
    int pageSize = 1000,
  }) async => _unexpected();
  @override
  Future<List<Map<String, dynamic>>> fetchPlantRowsPage({
    required int from,
    required int to,
  }) async => _unexpected();
  @override
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows() async =>
      _unexpected();
  @override
  Future<List<Map<String, dynamic>>> fetchZonesRows() async => _unexpected();
  @override
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId) async =>
      _unexpected();
}
