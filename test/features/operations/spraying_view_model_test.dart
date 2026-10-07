import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/spraying_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_geometry_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_view_model.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/local_sprayings_modal.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/spraying_review_action_bar.dart';

class FakeLocationService implements LocationService {
  final _controller = StreamController<LocationResult>.broadcast();
  LocationResult current = const LocationResult.serviceDisabled();

  @override
  Future<LocationResult> getCurrentLocation() async => current;

  @override
  Stream<LocationResult> watchLocation() => _controller.stream;

  void emit(LocationResult result) {
    current = result;
    _controller.add(result);
  }

  void dispose() {
    _controller.close();
  }
}

class FakeSprayingRepository implements SprayingRepository {
  final Map<String, SprayingOperation> operations = {};
  bool syncShouldSucceed = true;
  int syncCallCount = 0;

  @override
  Future<void> saveOperation(SprayingOperation op) async {
    operations[op.localId] = op;
  }

  @override
  Future<void> saveRoute(String operationLocalId, SprayingRoute route) async {
    final existing = operations[operationLocalId];
    if (existing != null) {
      operations[operationLocalId] = existing.copyWith(route: route);
    }
  }

  @override
  Future<void> addTrackPoint(
    String operationLocalId,
    SprayingTrackPoint trackPoint,
  ) async {
    final existing = operations[operationLocalId];
    if (existing != null) {
      operations[operationLocalId] = existing.copyWith(
        trackPoints: [...existing.trackPoints, trackPoint],
      );
    }
  }

  @override
  Future<void> addTrackPoints(
    String operationLocalId,
    List<SprayingTrackPoint> trackPoints,
  ) async {
    final existing = operations[operationLocalId];
    if (existing != null) {
      operations[operationLocalId] = existing.copyWith(
        trackPoints: [...existing.trackPoints, ...trackPoints],
      );
    }
  }

  @override
  Future<void> saveInputs(
    String operationLocalId,
    List<SprayingInput> inputs,
  ) async {
    final existing = operations[operationLocalId];
    if (existing != null) {
      operations[operationLocalId] = existing.copyWith(inputs: inputs);
    }
  }

  @override
  Future<void> saveConfirmedPlants(
    String operationLocalId,
    List<SprayingConfirmedPlant> confirmedPlants,
  ) async {
    final existing = operations[operationLocalId];
    if (existing != null) {
      operations[operationLocalId] = existing.copyWith(
        confirmedPlants: confirmedPlants,
      );
    }
  }

  @override
  Future<List<SprayingOperation>> listOperations() async {
    return operations.values.toList();
  }

  @override
  Future<SprayingOperation?> getOperation(String localId) async {
    return operations[localId];
  }

  @override
  Future<void> deleteOperation(String localId) async {
    operations.remove(localId);
  }

  @override
  Future<SprayingSyncResult> syncOperation(String localId) async {
    syncCallCount++;
    if (!syncShouldSucceed) {
      throw Exception('Network error during sync');
    }
    final existing = operations[localId];
    if (existing != null) {
      operations[localId] = existing.copyWith(
        syncStatus: SprayingSyncStatus.synced,
        remoteFieldOperationId: 'remote-field-op-uuid',
        syncedAt: DateTime.now().toUtc(),
      );
    }
    return SprayingSyncResult(
      fieldOperationId: 'remote-field-op-uuid',
      routeId: 'remote-route-uuid',
      trackPointsCount: existing?.trackPoints.length ?? 0,
      inputsCount: existing?.inputs.length ?? 0,
      confirmedPlantsCount: existing?.confirmedPlants.length ?? 0,
      syncedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<int> syncAllReviewed() async {
    int count = 0;
    for (final op in operations.values) {
      if (op.syncStatus == SprayingSyncStatus.reviewed) {
        await syncOperation(op.localId);
        count++;
      }
    }
    return count;
  }

  @override
  Future<List<SprayingConfirmedPlant>> calculateAffectedPlants({
    required SprayingOperation operation,
    required List<InspectionPlant> candidatePlants,
    double maxDistanceMeters = 9.0,
  }) async {
    const geometry = SprayingGeometryService();
    return geometry.calculateAffectedPlants(
      candidatePlants: candidatePlants,
      trackPoints: operation.trackPoints,
      maxDistanceMeters: maxDistanceMeters,
    );
  }
}

class FakeInspectionRepository implements InspectionRepository {
  InspectionSnapshot? snapshot;

  @override
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false}) async {
    return snapshot;
  }

  @override
  Future<List<OccurrenceType>> getCatalog() async => [];

  @override
  Future<void> togglePlantOccurrence(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  }) async {}

  @override
  Future<LocalInspection?> finalizeInspection() async => null;

  @override
  Future<List<LocalInspection>> listLocalInspections() async => [];

  @override
  Future<bool> syncPending() async => true;

  @override
  Future<bool> syncPendingAddedPlants() async => true;

  @override
  Future<List<AddedInspectionPlant>> listAddedPlants() async => [];

  @override
  Future<void> removeAddedPlant(String localId) async {}

  @override
  Future<AddedInspectionPlant> addPlant({
    required double latitude,
    required double longitude,
    required bool nonExistent,
    String? zoneId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<InspectionChange>> getInspectionChanges(
    String inspectionId,
  ) async => [];

  @override
  Future<void> removePlantFromInspection(
    String inspectionId,
    String plantId,
  ) async {}

  @override
  Future<void> setPlantNonExistent(String plantId, bool nonExistent) async {}
}

class FakeZonesRepository implements ZonesRepository {
  List<Zone> zones = [];
  Map<String, List<RegionPoint>> pointsByZone = {};

  @override
  Future<List<Zone>> fetchZones() async => zones;

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async =>
      pointsByZone[zoneId] ?? [];
}

void main() {
  testWidgets('start button shows translucent signal wait and can cancel', (
    tester,
  ) async {
    final phone = FakeLocationService();
    final vm = SprayingViewModel(
      sprayingRepository: FakeSprayingRepository(),
      inspectionRepository: FakeInspectionRepository(),
      locationService: phone,
      zonesRepository: FakeZonesRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SprayingView(
          viewModel: vm,
          mapBuilder: (_, _) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('action-spraying-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('btn-start-spraying')));
    await tester.pump();
    expect(find.text('Aguardando sinal estabilizar'), findsOneWidget);
    expect(vm.sessionState, SprayingSessionState.idle);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(vm.isPreparingSession, isFalse);
    expect(vm.currentOperation, isNull);

    await tester.pumpWidget(const SizedBox());
    vm.dispose();
    phone.dispose();
  });

  group('Spraying RPC Serialization', () {
    test('toRpcPayload produces compliant JSON structure', () {
      final now = DateTime.utc(2026, 10, 2, 10, 0, 0);
      final operation = SprayingOperation(
        localId: 'op-local-123',
        zoneId: 'zone-abc-456',
        startedAt: now,
        finishedAt: now.add(const Duration(minutes: 30)),
        operatorName: 'Carlos Silva',
        title: 'Pulverização Talhão 2',
        machineName: 'Jacto Advance',
        tractorIdentifier: 'Trator 01',
        notes: 'Sem vento',
        route: SprayingRoute(
          localId: 'route-1',
          geojson: const {
            'type': 'LineString',
            'coordinates': [
              [-47.8, -21.1],
              [-47.9, -21.2],
            ],
          },
          distanceMeters: 520.5,
          startedAt: now,
          finishedAt: now.add(const Duration(minutes: 30)),
        ),
        trackPoints: [
          SprayingTrackPoint(
            localId: 'tp-1',
            recordedAt: now,
            latitude: -21.1,
            longitude: -47.8,
            accuracyM: 4.5,
          ),
        ],
        inputs: const [
          SprayingInput(
            localId: 'input-1',
            inputType: 'fungicide',
            productName: 'Score Flexi',
            activeIngredient: 'Difenoconazol',
            dose: 0.5,
            doseUnit: 'L/ha',
            totalQuantity: 20.0,
            totalQuantityUnit: 'L',
          ),
        ],
        confirmedPlants: [
          SprayingConfirmedPlant(
            localId: 'cp-1',
            plantId: 'plant-100',
            matchSource: SprayingMatchSource.autoMatched,
            matchedAt: now,
            distanceMeters: 4.2,
          ),
        ],
      );

      final payload = operation.toRpcPayload(deviceId: 'device-xyz-789');

      expect(payload['localOperationId'], equals('op-local-123'));
      expect(payload['deviceId'], equals('device-xyz-789'));

      final opMap = payload['operation'] as Map<String, dynamic>;
      expect(opMap['zoneId'], equals('zone-abc-456'));
      expect(opMap['operatorName'], equals('Carlos Silva'));
      expect(opMap['title'], equals('Pulverização Talhão 2'));
      expect(opMap['machineName'], equals('Jacto Advance'));
      expect(opMap['tractorIdentifier'], equals('Trator 01'));
      expect(opMap['notes'], equals('Sem vento'));

      final routeMap = payload['route'] as Map<String, dynamic>;
      expect(routeMap['localId'], equals('route-1'));
      expect(routeMap['distanceMeters'], equals(520.5));

      final trackPoints = payload['trackPoints'] as List;
      expect(trackPoints.length, equals(1));
      expect((trackPoints.first as Map)['latitude'], equals(-21.1));

      final inputs = payload['inputs'] as List;
      expect(inputs.length, equals(1));
      expect((inputs.first as Map)['productName'], equals('Score Flexi'));

      final plants = payload['confirmedPlants'] as List;
      expect(plants.length, equals(1));
      expect((plants.first as Map)['matchSource'], equals('auto_matched'));
      expect((plants.first as Map)['distanceMeters'], equals(4.2));
    });

    test(
      'SprayingSyncResult.fromRpc correctly parses camelCase and snake_case',
      () {
        final snakeCaseResponse = {
          'field_operation_id': 'op-remote-1',
          'route_id': 'route-remote-1',
          'track_points_count': 10,
          'inputs_count': 2,
          'confirmed_plants_count': 15,
          'synced_at': '2026-10-02T12:00:00.000Z',
        };
        final res1 = SprayingSyncResult.fromRpc(snakeCaseResponse);
        expect(res1.fieldOperationId, equals('op-remote-1'));
        expect(res1.routeId, equals('route-remote-1'));
        expect(res1.trackPointsCount, equals(10));
        expect(res1.inputsCount, equals(2));
        expect(res1.confirmedPlantsCount, equals(15));

        final camelCaseResponse = {
          'fieldOperationId': 'op-remote-2',
          'routeId': 'route-remote-2',
          'trackPointsCount': 5,
          'inputsCount': 1,
          'confirmedPlantsCount': 8,
          'syncedAt': '2026-10-02T12:30:00.000Z',
        };
        final res2 = SprayingSyncResult.fromRpc(camelCaseResponse);
        expect(res2.fieldOperationId, equals('op-remote-2'));
        expect(res2.routeId, equals('route-remote-2'));
        expect(res2.trackPointsCount, equals(5));
        expect(res2.inputsCount, equals(1));
        expect(res2.confirmedPlantsCount, equals(8));

        expect(
          () => SprayingSyncResult.fromRpc({
            'field_operation_id': 'op-remote-3',
            'route_id': 'route-remote-3',
            'track_points_count': 5,
            'synced_at': '2026-10-02T12:30:00.000Z',
          }),
          throwsFormatException,
        );
      },
    );
  });

  group('SprayingViewModel Session Lifecycle', () {
    late FakeSprayingRepository sprayingRepo;
    late FakeInspectionRepository inspectionRepo;
    late FakeZonesRepository zonesRepo;
    late FakeLocationService locationService;
    late SprayingViewModel viewModel;

    setUp(() {
      sprayingRepo = FakeSprayingRepository();
      inspectionRepo = FakeInspectionRepository();
      zonesRepo = FakeZonesRepository();
      locationService = FakeLocationService();

      viewModel = SprayingViewModel(
        sprayingRepository: sprayingRepo,
        inspectionRepository: inspectionRepo,
        locationService: locationService,
        zonesRepository: zonesRepo,
      );
    });

    tearDown(() {
      viewModel.dispose();
      locationService.dispose();
    });

    test(
      'initial state is idle with empty track points and reviewed plants',
      () {
        expect(viewModel.sessionState, equals(SprayingSessionState.idle));
        expect(viewModel.activeTrackPoints, isEmpty);
        expect(viewModel.reviewedPlants, isEmpty);
        expect(viewModel.totalDistanceMeters, equals(0.0));
      },
    );

    test('startSession initializes operation and recording state', () async {
      await viewModel.startSession(
        zoneId: 'zone-1',
        operatorName: 'João da Silva',
        title: 'Aplicação 1',
        machineName: 'Jacto',
        tractorIdentifier: 'JD 6110',
      );

      expect(viewModel.sessionState, equals(SprayingSessionState.recording));
      expect(viewModel.currentOperation, isNotNull);
      expect(viewModel.currentOperation!.zoneId, equals('zone-1'));
      expect(viewModel.currentOperation!.operatorName, equals('João da Silva'));
      expect(viewModel.currentOperation!.title, equals('Aplicação 1'));
    });

    test('prepares session until fresh GPS samples stabilize', () async {
      final now = DateTime.now().toUtc();
      viewModel.prepareSessionStart();
      expect(viewModel.isPreparingSession, isTrue);
      expect(viewModel.sessionState, SprayingSessionState.idle);

      for (var seconds = -2; seconds <= 0; seconds++) {
        locationService.emit(
          LocationResult.available(
            UserLocation(
              latitude: -21.177,
              longitude: -47.81,
              accuracy: 5,
              timestamp: now.add(Duration(seconds: seconds)),
            ),
          ),
        );
      }
      await pumpEventQueue();

      expect(viewModel.isPreparingSession, isFalse);
      expect(viewModel.sessionState, SprayingSessionState.recording);
      expect(viewModel.activeTrackPoints, hasLength(1));
    });

    test('cancelled preparation never creates a spraying session', () async {
      viewModel.prepareSessionStart();
      viewModel.cancelSessionPreparation();
      expect(viewModel.isPreparingSession, isFalse);

      final now = DateTime.now().toUtc();
      for (var seconds = -2; seconds <= 0; seconds++) {
        locationService.emit(
          LocationResult.available(
            UserLocation(
              latitude: -21.177,
              longitude: -47.81,
              accuracy: 5,
              timestamp: now.add(Duration(seconds: seconds)),
            ),
          ),
        );
      }
      await pumpEventQueue();
      expect(viewModel.sessionState, SprayingSessionState.idle);
      expect(viewModel.currentOperation, isNull);
    });

    test('GPS tracking records track points when recording', () async {
      viewModel.startLocationTracking();

      await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');

      // Emit first location
      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177000,
            longitude: -47.810000,
            accuracy: 5.0,
          ),
        ),
      );
      await pumpEventQueue();

      expect(viewModel.activeTrackPoints.length, equals(1));
      expect(viewModel.userLocation, isNotNull);

      // A single displaced sample must not extend the route.
      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177060,
            longitude: -47.810000,
            accuracy: 4.0,
          ),
        ),
      );
      await pumpEventQueue();
      expect(viewModel.activeTrackPoints.length, equals(1));

      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177065,
            longitude: -47.810000,
            accuracy: 4.0,
          ),
        ),
      );
      await pumpEventQueue();

      expect(viewModel.activeTrackPoints.length, equals(2));
      expect(viewModel.totalDistanceMeters, greaterThan(5.0));
      expect(viewModel.polylines.isNotEmpty, isTrue);

      viewModel.stopLocationTracking();
    });

    test('GPS excursion does not move marker or recorded route', () async {
      viewModel.startLocationTracking();
      await viewModel.startSession(zoneId: 'zone-1');

      locationService.emit(
        const LocationResult.available(
          UserLocation(latitude: -21.177, longitude: -47.81, accuracy: 3),
        ),
      );
      await pumpEventQueue();
      final initialLocation = viewModel.userLocation;

      locationService.emit(
        const LocationResult.available(
          UserLocation(latitude: -21.1765, longitude: -47.81, accuracy: 3),
        ),
      );
      await pumpEventQueue();

      expect(viewModel.userLocation, same(initialLocation));
      expect(viewModel.activeTrackPoints, hasLength(1));
      expect(viewModel.polylines, isEmpty);

      locationService.emit(
        const LocationResult.available(
          UserLocation(latitude: -21.177, longitude: -47.81, accuracy: 3),
        ),
      );
      await pumpEventQueue();
      expect(viewModel.userLocation, same(initialLocation));
      expect(viewModel.activeTrackPoints, hasLength(1));
    });

    test('pauseSession and resumeSession manage state correctly', () async {
      await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');
      expect(viewModel.sessionState, equals(SprayingSessionState.recording));

      viewModel.pauseSession();
      expect(viewModel.sessionState, equals(SprayingSessionState.paused));

      // Emitting location while paused does not add track points
      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177000,
            longitude: -47.810000,
            accuracy: 5.0,
          ),
        ),
      );
      expect(viewModel.activeTrackPoints, isEmpty);

      viewModel.resumeSession();
      expect(viewModel.sessionState, equals(SprayingSessionState.recording));
    });

    test(
      'finishSession saves operation locally in draft status offline',
      () async {
        viewModel.startLocationTracking();
        await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');

        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177000,
              longitude: -47.810000,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();
        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177050,
              longitude: -47.810050,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();
        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177051,
              longitude: -47.810050,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();

        await viewModel.finishSession();

        expect(viewModel.sessionState, equals(SprayingSessionState.idle));
        expect(viewModel.currentOperation, isNull);
        expect(sprayingRepo.operations.length, equals(1));
        final savedOp = sprayingRepo.operations.values.first;
        expect(savedOp.syncStatus, equals(SprayingSyncStatus.draft));
        expect(savedOp.route, isNotNull);
        expect(savedOp.trackPoints.length, equals(2));
      },
    );

    test('startReviewingOperation calculates affected plants within 9m buffer and loads review state', () async {
      // Set candidate plants in inspection snapshot
      inspectionRepo.snapshot = InspectionSnapshot(
        plants: [
          InspectionPlant(
            id: 'plant-near',
            description: 'Planta Próxima',
            latitude: -21.177020,
            longitude: -47.810020,
            zoneId: 'zone-1',
          ),
          InspectionPlant(
            id: 'plant-far',
            description: 'Planta Longe',
            latitude: -21.180000,
            longitude: -47.820000,
            zoneId: 'zone-1',
          ),
        ],
        types: const [],
        loadedAt: DateTime.now(),
      );
      await viewModel.loadPlants();

      viewModel.startLocationTracking();
      await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');

      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177000,
            longitude: -47.810000,
            accuracy: 3.0,
          ),
        ),
      );
      await pumpEventQueue();
      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177050,
            longitude: -47.810050,
            accuracy: 3.0,
          ),
        ),
      );
      await pumpEventQueue();
      locationService.emit(
        const LocationResult.available(
          UserLocation(
            latitude: -21.177051,
            longitude: -47.810050,
            accuracy: 3.0,
          ),
        ),
      );
      await pumpEventQueue();

      await viewModel.finishSession();
      final savedOp = sprayingRepo.operations.values.first;
      expect(savedOp.trackPoints.length, 2);

      await viewModel.startReviewingOperation(savedOp);

      expect(viewModel.isReviewing, isTrue);
      expect(viewModel.reviewingOperation, isNotNull);
      expect(viewModel.reviewedPlants.length, equals(1));
      expect(viewModel.reviewedPlants.first.plantId, equals('plant-near'));
      expect(
        viewModel.reviewedPlants.first.matchSource,
        equals(SprayingMatchSource.autoMatched),
      );
      expect(viewModel.polylines.isNotEmpty, isTrue);
    });

    test('toggleAffectedPlant allows manual toggling of plants', () {
      final plant = InspectionPlant(
        id: 'plant-custom-1',
        description: 'Planta Customizada',
        latitude: -21.177,
        longitude: -47.810,
      );

      expect(viewModel.reviewedPlantIds.contains('plant-custom-1'), isFalse);

      viewModel.toggleAffectedPlant(plant);
      expect(viewModel.reviewedPlantIds.contains('plant-custom-1'), isTrue);
      expect(
        viewModel.reviewedPlants.first.matchSource,
        equals(SprayingMatchSource.manualAdded),
      );

      viewModel.toggleAffectedPlant(plant);
      expect(viewModel.reviewedPlantIds.contains('plant-custom-1'), isFalse);
    });

    test(
      'saveInputsAndComplete validates inputs and saves to repository',
      () async {
        viewModel.startLocationTracking();
        await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');
        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177000,
              longitude: -47.810000,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();
        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177050,
              longitude: -47.810050,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();
        locationService.emit(
          const LocationResult.available(
            UserLocation(
              latitude: -21.177051,
              longitude: -47.810050,
              accuracy: 3.0,
            ),
          ),
        );
        await pumpEventQueue();
        await viewModel.finishSession();
        final savedOp = sprayingRepo.operations.values.first;
        await viewModel.startReviewingOperation(savedOp);

        // Empty inputs should fail validation
        await viewModel.saveInputsAndComplete(inputs: []);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.isReviewing, isTrue);

        // With valid inputs
        await viewModel.saveInputsAndComplete(
          inputs: const [
            SprayingInput(
              localId: 'inp-1',
              inputType: 'fungicide',
              productName: 'Score',
            ),
          ],
          notes: 'Concluído normalmente',
        );

        expect(viewModel.sessionState, equals(SprayingSessionState.idle));
        expect(viewModel.isReviewing, isFalse);
        expect(viewModel.feedbackMessage, isNotNull);
        expect(viewModel.currentOperation, isNull);
        expect(sprayingRepo.operations.length, equals(1));
        expect(
          sprayingRepo.operations.values.first.syncStatus,
          equals(SprayingSyncStatus.reviewed),
        );
      },
    );

    test(
      'syncOperation performs atomic synchronization with Supabase RPC',
      () async {
        // Create a reviewed operation in local repo
        final op = SprayingOperation(
          localId: 'op-ready-1',
          zoneId: 'zone-1',
          startedAt: DateTime.now().toUtc(),
          finishedAt: DateTime.now().toUtc(),
          operatorName: 'João',
          syncStatus: SprayingSyncStatus.reviewed,
          route: SprayingRoute(
            localId: 'r-1',
            geojson: const {'type': 'LineString', 'coordinates': []},
            distanceMeters: 100.0,
            startedAt: DateTime.now().toUtc(),
            finishedAt: DateTime.now().toUtc(),
          ),
        );
        await sprayingRepo.saveOperation(op);
        await viewModel.loadLocalOperations();

        expect(viewModel.localOperations.length, equals(1));

        await viewModel.syncOperation('op-ready-1');

        expect(sprayingRepo.syncCallCount, equals(1));
        expect(viewModel.feedbackMessage, contains('Sincronizado com sucesso'));
        expect(
          sprayingRepo.operations['op-ready-1']!.syncStatus,
          equals(SprayingSyncStatus.synced),
        );
      },
    );

    test(
      'uses the reviewed plants zone when completing an operation',
      () async {
        final now = DateTime.now().toUtc();
        inspectionRepo.snapshot = InspectionSnapshot(
          plants: [InspectionPlant(id: 'plant-b', zoneId: 'zone-b')],
          types: const [],
          loadedAt: now,
        );
        final operation = SprayingOperation(
          localId: 'op-zone',
          zoneId: 'zone-a',
          startedAt: now,
          finishedAt: now,
          operatorName: 'Operador',
          confirmedPlants: const [
            SprayingConfirmedPlant(
              localId: 'match-b',
              plantId: 'plant-b',
              matchSource: SprayingMatchSource.autoMatched,
            ),
          ],
        );
        await sprayingRepo.saveOperation(operation);
        await viewModel.startReviewingOperation(operation);

        final saved = await viewModel.saveInputsAndComplete(
          inputs: const [
            SprayingInput(
              localId: 'input-1',
              inputType: 'fungicide',
              productName: 'Produto',
            ),
          ],
        );

        expect(saved, isTrue);
        expect(sprayingRepo.operations['op-zone']?.zoneId, 'zone-b');
        expect(sprayingRepo.operations['op-zone']?.confirmedPlants.length, 1);
        expect(sprayingRepo.operations['op-zone']?.inputs.length, 1);
      },
    );

    test('keeps review open when selected plants span zones', () async {
      final now = DateTime.now().toUtc();
      inspectionRepo.snapshot = InspectionSnapshot(
        plants: [
          InspectionPlant(id: 'plant-a', zoneId: 'zone-a'),
          InspectionPlant(id: 'plant-b', zoneId: 'zone-b'),
        ],
        types: const [],
        loadedAt: now,
      );
      final operation = SprayingOperation(
        localId: 'op-mixed',
        zoneId: 'zone-a',
        startedAt: now,
        finishedAt: now,
        operatorName: 'Operador',
        confirmedPlants: const [
          SprayingConfirmedPlant(
            localId: 'match-a',
            plantId: 'plant-a',
            matchSource: SprayingMatchSource.autoMatched,
          ),
          SprayingConfirmedPlant(
            localId: 'match-b',
            plantId: 'plant-b',
            matchSource: SprayingMatchSource.autoMatched,
          ),
        ],
      );
      await sprayingRepo.saveOperation(operation);
      await viewModel.startReviewingOperation(operation);

      final saved = await viewModel.saveInputsAndComplete(
        inputs: const [
          SprayingInput(
            localId: 'input-1',
            inputType: 'fungicide',
            productName: 'Produto',
          ),
        ],
      );

      expect(saved, isFalse);
      expect(viewModel.isReviewing, isTrue);
      expect(viewModel.errorMessage, contains('talhões diferentes'));
      expect(
        sprayingRepo.operations['op-mixed']?.syncStatus,
        SprayingSyncStatus.draft,
      );
    });

    testWidgets('review count and actions stay aligned across widths', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      final operation = SprayingOperation(
        localId: 'op-layout',
        zoneId: 'zone-a',
        startedAt: now,
        finishedAt: now,
        operatorName: 'Operador',
        confirmedPlants: const [
          SprayingConfirmedPlant(
            localId: 'match-a',
            plantId: 'plant-a',
            matchSource: SprayingMatchSource.autoMatched,
          ),
        ],
      );
      await viewModel.startReviewingOperation(operation);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final width in [320.0, 384.0, 420.0, 768.0, 1024.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SprayingReviewActionBar(viewModel: viewModel),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final count = tester.getRect(
          find.byKey(const ValueKey('review-plants-count')),
        );
        final list = tester.getRect(
          find.byKey(const ValueKey('btn-review-plants-list')),
        );
        final inputs = tester.getRect(
          find.byKey(const ValueKey('btn-review-proceed-inputs')),
        );
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Plantas atingidas'), findsOneWidget);
        expect(list.top - count.bottom, greaterThanOrEqualTo(8));
        expect(inputs.left - list.right, greaterThanOrEqualTo(8));
        expect(inputs.top, list.top);
        expect(inputs.width, list.width);
        expect(list.height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull, reason: 'width: $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('saved operations show an undefined operator placeholder', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      await sprayingRepo.saveOperation(
        SprayingOperation(
          localId: 'op-without-operator',
          zoneId: 'zone-a',
          startedAt: now,
          finishedAt: now,
          operatorName: 'Operador',
        ),
      );
      await sprayingRepo.saveOperation(
        SprayingOperation(
          localId: 'op-with-operator',
          zoneId: 'zone-a',
          startedAt: now,
          finishedAt: now,
          operatorName: 'Maria',
        ),
      );
      await viewModel.loadLocalOperations();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalSprayingsModal(viewModel: viewModel)),
        ),
      );

      expect(find.text('Operador: A definir'), findsOneWidget);
      expect(find.text('Operador: Maria'), findsOneWidget);
      expect(find.text('Operador: Operador'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sync errors remain visible in the saved operations sheet', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      await sprayingRepo.saveOperation(
        SprayingOperation(
          localId: 'op-sync-error',
          zoneId: 'zone-a',
          startedAt: now,
          finishedAt: now,
          operatorName: 'Operador',
          syncStatus: SprayingSyncStatus.reviewed,
        ),
      );
      await viewModel.loadLocalOperations();
      sprayingRepo.syncShouldSucceed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalSprayingsModal(viewModel: viewModel)),
        ),
      );

      await viewModel.syncOperation('op-sync-error');
      await tester.pump();

      expect(find.textContaining('Network error during sync'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('cancelSession removes ongoing operation and resets state', () async {
      await viewModel.startSession(zoneId: 'zone-1', operatorName: 'João');
      final opId = viewModel.currentOperation!.localId;
      expect(sprayingRepo.operations.containsKey(opId), isTrue);

      await viewModel.cancelSession();

      expect(viewModel.sessionState, equals(SprayingSessionState.idle));
      expect(viewModel.currentOperation, isNull);
      expect(sprayingRepo.operations.containsKey(opId), isFalse);
    });
  });
}
