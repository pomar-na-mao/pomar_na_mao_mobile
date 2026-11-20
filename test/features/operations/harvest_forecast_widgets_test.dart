import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/harvest_forecast_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/harvest_forecast_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/harvest_forecast_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/harvest_forecast_view_model.dart';

class _StreamLocationService implements LocationService {
  final controller = StreamController<LocationResult>.broadcast();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.error();

  @override
  Stream<LocationResult> watchLocation() => controller.stream;
}

class _InMemoryHarvestForecastRepository implements HarvestForecastRepository {
  final List<HarvestForecastMarking> _items = [];
  int _counter = 0;
  int syncCalls = 0;

  @override
  String createLocalId() => 'local-${++_counter}';

  @override
  Future<List<InspectionPlant>> loadPlants({bool forceRemote = false}) async =>
      [
        InspectionPlant(
          id: 'plant-1',
          latitude: -23.1,
          longitude: -46.1,
          zoneId: 'zone-1',
        ),
      ];

  @override
  Future<HarvestForecastMarking> save({
    String? localId,
    required double latitude,
    required double longitude,
    required HarvestForecastClassification classification,
    DateTime? createdAt,
  }) async {
    final id = localId ?? createLocalId();
    final marking = HarvestForecastMarking(
      localId: id,
      latitude: latitude,
      longitude: longitude,
      classification: classification,
      createdAt: createdAt ?? DateTime.utc(2026, 11, 19, 10, 0, _counter),
    );
    _items.insert(0, marking);
    return marking;
  }

  @override
  Future<List<HarvestForecastMarking>> list() async =>
      List<HarvestForecastMarking>.unmodifiable(_items);

  @override
  Future<HarvestForecastMarking?> updateClassification({
    required String localId,
    required HarvestForecastClassification classification,
  }) async {
    final index = _items.indexWhere((m) => m.localId == localId);
    if (index == -1) return null;
    final updated = _items[index].copyWith(
      classification: classification,
      status: HarvestForecastSyncStatus.pending,
      clearError: true,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<bool> delete(String localId) async {
    final before = _items.length;
    _items.removeWhere((m) => m.localId == localId);
    return _items.length < before;
  }

  @override
  Future<bool> syncOne(String localId) async {
    syncCalls++;
    final index = _items.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        status: HarvestForecastSyncStatus.synced,
        remoteId: 'remote-$localId',
        remotePlantId: 'plant-1',
        remoteZoneId: 'zone-1',
        syncedAt: DateTime.utc(2026, 11, 19, 12),
      );
    }
    return true;
  }

  @override
  Future<bool> syncAll() async {
    syncCalls++;
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(
        status: HarvestForecastSyncStatus.synced,
        remoteId: 'remote-${_items[i].localId}',
        remotePlantId: 'plant-1',
        remoteZoneId: 'zone-1',
        syncedAt: DateTime.utc(2026, 11, 19, 12),
      );
    }
    return true;
  }
}

void main() {
  late _StreamLocationService locationService;
  late _InMemoryHarvestForecastRepository repository;
  late HarvestForecastViewModel viewModel;

  setUp(() {
    repository = _InMemoryHarvestForecastRepository();
    locationService = _StreamLocationService();
    viewModel = HarvestForecastViewModel(
      repository: repository,
      locationService: locationService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await locationService.controller.close();
  });

  testWidgets(
    'renders 5 circular buttons N, P, M, G, GG with click effect, plots marked points on map, opens point detail modal on marker tap, and manages saved markings',
    (tester) async {
      HarvestForecastMapConfig? lastConfig;
      await tester.pumpWidget(
        MaterialApp(
          home: HarvestForecastView(
            viewModel: viewModel,
            mapBuilder: (context, config) {
              lastConfig = config;
              return Stack(
                children: [
                  GestureDetector(
                    key: const ValueKey('fake-harvest-forecast-map'),
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (_) => config.onMapGestureStarted(),
                    onDoubleTap: () => config.onMapDoubleTap?.call(
                      const LatLng(-23.5555, -46.7777),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      children: [
                        for (final marking in config.markings)
                          TextButton(
                            key: ValueKey('map-marking-pin-${marking.localId}'),
                            onPressed: () =>
                                config.onSelectMarking?.call(marking),
                            child: Text(marking.classification.code),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 5 circular buttons exist on the same row
      for (final code in ['N', 'P', 'M', 'G', 'GG']) {
        expect(
          find.byKey(ValueKey('harvest-forecast-button-$code')),
          findsOneWidget,
        );
      }
      final nCenterY = tester
          .getCenter(find.byKey(const ValueKey('harvest-forecast-button-N')))
          .dy;
      for (final code in ['P', 'M', 'G', 'GG']) {
        expect(
          tester
              .getCenter(find.byKey(ValueKey('harvest-forecast-button-$code')))
              .dy,
          nCenterY,
        );
      }

      // Emit user location
      locationService.controller.add(
        LocationResult.available(
          UserLocation(
            latitude: -23.1234,
            longitude: -46.5678,
            accuracy: 4,
            timestamp: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lastConfig?.isFollowingUser, isTrue);

      // Simulate manual gesture / zoom on map -> suspends automatic follow
      await tester.tap(
        find.byKey(const ValueKey('fake-harvest-forecast-map')),
      );
      await tester.pumpAndSettle();
      expect(lastConfig?.isFollowingUser, isFalse);

      // Tap P and then GG; verify marked points appear on the map
      await tester.tap(find.byKey(const ValueKey('harvest-forecast-button-P')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-button-GG')),
      );
      await tester.pumpAndSettle();

      expect(lastConfig?.markings, hasLength(2));
      expect(
        find.byKey(const ValueKey('map-marking-pin-local-2')),
        findsOneWidget,
      );

      // Tap the marked point on the map to open the compact detail modal
      await tester.tap(find.byKey(const ValueKey('map-marking-pin-local-2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('harvest-forecast-point-modal')),
        findsOneWidget,
      );
      expect(find.text('Ponto Marcado'), findsOneWidget);
      expect(find.text('Previsão GG (Muito grande)'), findsOneWidget);

      // Change classification directly inside the point detail modal from GG to G
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-point-modal-edit-G')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Previsão G (Grande)'), findsOneWidget);

      // Close point detail modal
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-point-modal-close')),
      );
      await tester.pumpAndSettle();

      // Open Saved Markings modal
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-saved-markings')),
      );
      await tester.pumpAndSettle();

      // Newest marking (local-2, now G) appears at the top above older marking (local-1, P)
      final cardNewest = find.byKey(
        const ValueKey('harvest-forecast-saved-marking-local-2'),
      );
      final cardOldest = find.byKey(
        const ValueKey('harvest-forecast-saved-marking-local-1'),
      );
      expect(cardNewest, findsOneWidget);
      expect(cardOldest, findsOneWidget);
      expect(
        tester.getTopLeft(cardNewest).dy,
        lessThan(tester.getTopLeft(cardOldest).dy),
      );

      // Change classification of local-2 from G to M
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-edit-local-2-M')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Previsão M (Média)'), findsOneWidget);

      // Sync individual item local-2
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-sync-local-2')),
      );
      await tester.pumpAndSettle();
      expect(repository.syncCalls, 1);
      expect(find.text('Sincronizada'), findsOneWidget);

      // Delete item local-1
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-delete-local-1')),
      );
      await tester.pumpAndSettle();
      expect(cardOldest, findsNothing);

      // Close Saved Markings modal and double-tap on the map -> creates default N marking
      await tester.tap(
        find.byKey(const ValueKey('harvest-forecast-saved-close')),
      );
      await tester.pumpAndSettle();

      final mapFinder = find.byKey(const ValueKey('fake-harvest-forecast-map'));
      await tester.tap(mapFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(mapFinder);
      await tester.pumpAndSettle();

      expect(lastConfig?.markings, hasLength(2));
      expect(
        lastConfig?.markings.first.classification,
        HarvestForecastClassification.n,
      );
      expect(lastConfig?.markings.first.latitude, -23.5555);
      expect(lastConfig?.markings.first.longitude, -46.7777);
    },
  );
}
