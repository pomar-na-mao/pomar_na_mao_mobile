import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/harvest_forecast_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/harvest_forecast_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StreamLocationService implements LocationService {
  final controller = StreamController<LocationResult>.broadcast();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.error();

  @override
  Stream<LocationResult> watchLocation() => controller.stream;
}

class _FakeRemoteDataSource implements HarvestForecastRemoteDataSource {
  @override
  Future<List<HarvestForecastSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async {
    final markings = payload['markings'] as List<dynamic>;
    return [
      for (final item in markings)
        HarvestForecastSyncResult(
          localMarkingId: (item as Map<String, dynamic>)['localMarkingId']
              as String,
          id: 'remote-${item['localMarkingId']}',
          plantId: 'plant-1',
          zoneId: 'zone-1',
          syncedAt: DateTime.utc(2026, 11, 19, 13),
        ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late HarvestForecastDatabase forecastDb;
  late InspectionDatabase inspectionDb;
  late _StreamLocationService locationService;
  late HarvestForecastViewModel viewModel;
  var idCounter = 0;

  setUp(() async {
    idCounter = 0;
    tempDir = await Directory.systemTemp.createTemp('harvest_forecast_vm_');
    forecastDb = HarvestForecastDatabase(
      projectUrl: 'https://harvest-forecast-vm.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    inspectionDb = InspectionDatabase(
      projectUrl: 'https://harvest-forecast-vm.supabase.co',
      factory: databaseFactoryFfi,
      directory: tempDir.path,
    );
    final inspectionLocalStore = InspectionLocalStore(inspectionDb);
    await inspectionLocalStore.replaceSnapshot(
      InspectionSnapshot(
        plants: [
          InspectionPlant(
            id: 'plant-1',
            latitude: -23.1000,
            longitude: -46.1000,
            zoneId: 'zone-1',
          ),
        ],
        types: const [],
        loadedAt: DateTime.utc(2026, 11, 19),
      ),
    );
    final repository = DefaultHarvestForecastRepository(
      localStore: HarvestForecastLocalStore(
        forecastDb,
        newId: () => 'local-${++idCounter}',
        clock: () => DateTime.utc(2026, 11, 19, 10, 0, idCounter),
      ),
      remoteDataSource: _FakeRemoteDataSource(),
      inspectionLocalStore: inspectionLocalStore,
      refreshSharedCache: () async {},
    );
    locationService = _StreamLocationService();
    viewModel = HarvestForecastViewModel(
      repository: repository,
      locationService: locationService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await locationService.controller.close();
    await forecastDb.close();
    await inspectionDb.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('tracks location, builds route polyline and records classification', () async {
    await viewModel.initialize();
    expect(viewModel.plants, hasLength(1));

    // Without location, recording classification shows feedback and returns null
    final withoutLoc = await viewModel.recordClassification(
      HarvestForecastClassification.n,
    );
    expect(withoutLoc, isNull);
    expect(viewModel.errorMessage, isNotNull);

    viewModel.resumeLocation();
    locationService.controller.add(
      LocationResult.available(
        UserLocation(
          latitude: -23.1000,
          longitude: -46.1000,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.userLocation, isNotNull);
    expect(viewModel.routePoints, hasLength(1));
    expect(viewModel.polylines, isEmpty);

    // Move > 2.5m to generate route polyline and directional course
    final baseTime = DateTime.now();
    locationService.controller.add(
      LocationResult.available(
        UserLocation(
          latitude: -23.10005,
          longitude: -46.10005,
          accuracy: 5,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      ),
    );
    locationService.controller.add(
      LocationResult.available(
        UserLocation(
          latitude: -23.1001,
          longitude: -46.1001,
          accuracy: 5,
          timestamp: baseTime.add(const Duration(milliseconds: 400)),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.routePoints, hasLength(2));
    expect(viewModel.polylines, hasLength(1));
    expect(viewModel.mapLocation.course, isNotNull);

    // Record P and then GG; GG should be at index 0 (newest at top)
    await viewModel.recordClassification(HarvestForecastClassification.p);
    await viewModel.recordClassification(HarvestForecastClassification.gg);
    expect(viewModel.markings, hasLength(2));
    expect(
      viewModel.markings.first.classification,
      HarvestForecastClassification.gg,
    );
    expect(
      viewModel.markings.last.classification,
      HarvestForecastClassification.p,
    );

    // Update classification, sync and delete
    final topId = viewModel.markings.first.localId;
    expect(
      await viewModel.updateClassification(
        topId,
        HarvestForecastClassification.m,
      ),
      isTrue,
    );
    expect(
      viewModel.markings.first.classification,
      HarvestForecastClassification.m,
    );

    expect(await viewModel.syncOne(topId), isTrue);
    expect(
      viewModel.markings.first.status,
      HarvestForecastSyncStatus.synced,
    );

    expect(await viewModel.syncAll(), isTrue);
    expect(
      viewModel.markings.every(
        (m) => m.status == HarvestForecastSyncStatus.synced,
      ),
      isTrue,
    );

    expect(await viewModel.deleteMarking(topId), isTrue);
    expect(viewModel.markings, hasLength(1));
  });
}
