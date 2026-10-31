import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zones_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/activity_view_model.dart';

void main() {
  late _Repository repository;
  late ActivityViewModel viewModel;

  setUp(() {
    repository = _Repository();
    viewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
    );
  });

  tearDown(() => viewModel.dispose());

  test('loads plants, catalog and saved queue', () async {
    await viewModel.initialize();

    expect(viewModel.status, ActivityLoadStatus.success);
    expect(viewModel.plants.first.description, 'P1');
    expect(viewModel.catalog.single.name, 'Produto');
    expect(viewModel.entries, isEmpty);
  });

  test(
    'keeps drawing after save failure and clears only after success',
    () async {
      viewModel.addPoint(const ActivityPoint(-21, -47));
      viewModel.addPoint(const ActivityPoint(-21.01, -47.01));
      repository.failSave = true;

      expect(
        await viewModel.save(
          activity: 'roçagem',
          performedAt: DateTime(2026, 10, 30, 12, 30),
          responsible: 'João',
          inputs: const [],
        ),
        isFalse,
      );
      expect(viewModel.points, hasLength(2));
      expect(viewModel.errorMessage, isNotNull);

      repository.failSave = false;
      expect(
        await viewModel.save(
          activity: 'roçagem',
          performedAt: DateTime(2026, 10, 30, 12, 30),
          responsible: 'João',
          inputs: const [],
        ),
        isTrue,
      );
      expect(viewModel.points, isEmpty);
      expect(viewModel.entries.single.activity, 'roçagem');
    },
  );

  test('sync all blocks a duplicate touch while request is active', () async {
    repository.syncCompleter = Completer<bool>();
    final first = viewModel.syncAll();
    final second = await viewModel.syncAll();

    expect(second, isFalse);
    repository.syncCompleter!.complete(true);
    expect(await first, isTrue);
    expect(repository.syncCalls, 1);
  });

  test('filters plants and loads the selected zone geometry', () async {
    final filteredViewModel = ActivityViewModel(
      repository: repository,
      locationService: _NoLocationService(),
      zonesRepository: _ZonesRepository(),
    );
    addTearDown(filteredViewModel.dispose);
    await filteredViewModel.initialize();

    await filteredViewModel.setZoneFilter('zone-a');

    expect(filteredViewModel.isFiltered, isTrue);
    expect(filteredViewModel.plants.single.id, 'plant-1');
    expect(filteredViewModel.selectedZone?.name, 'Zona A');
    expect(filteredViewModel.selectedZonePoints, hasLength(4));

    await filteredViewModel.setZoneFilter(null);
    expect(filteredViewModel.isFiltered, isFalse);
    expect(filteredViewModel.plants, hasLength(2));
  });
}

class _Repository implements ActivityRepository {
  final entries = <ActivityEntry>[];
  var sequence = 0;
  var failSave = false;
  var syncCalls = 0;
  Completer<bool>? syncCompleter;

  @override
  String createLocalId() => 'local-${sequence++}';

  @override
  Future<ActivitySnapshot> loadSnapshot({bool forceRemote = false}) async =>
      ActivitySnapshot(
        plants: [
          InspectionPlant(
            id: 'plant-1',
            latitude: -21,
            longitude: -47,
            description: 'P1',
            zoneId: 'zone-a',
          ),
          InspectionPlant(
            id: 'plant-2',
            latitude: -22,
            longitude: -48,
            description: 'P2',
            zoneId: 'zone-b',
          ),
        ],
        inputs: const [
          FieldInputCatalogItem(
            id: 'input-1',
            name: 'Produto',
            type: 'FUNGICIDE',
          ),
        ],
      );

  @override
  Future<List<ActivityEntry>> list() async => List.of(entries);

  @override
  Future<bool> deleteLocal(String localId) async {
    final previousLength = entries.length;
    entries.removeWhere((entry) => entry.localId == localId);
    return entries.length < previousLength;
  }

  @override
  Future<ActivityEntry> save({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    List<ActivityInput> inputs = const [],
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
  }) async {
    if (failSave) throw StateError('offline write failed');
    final entry = ActivityEntry(
      localId: createLocalId(),
      geometry: geometry,
      activity: activity,
      performedAt: performedAt,
      responsible: responsible,
      mixtureId: mixture?.id,
      mixtureNameSnapshot: mixture?.name,
      machineId: machine?.id,
      machineNameSnapshot: machine?.name,
      machineBrandSnapshot: machine?.brand,
      inputs: inputs,
    );
    entries.add(entry);
    return entry;
  }

  @override
  Future<bool> syncAll() {
    syncCalls++;
    return syncCompleter?.future ?? Future.value(true);
  }

  @override
  Future<bool> syncOne(String localId) async => true;
}

class _ZonesRepository implements ZonesRepository {
  @override
  Future<List<Zone>> fetchZones() async => const [
    Zone(id: 'zone-a', name: 'Zona A'),
    Zone(id: 'zone-b', name: 'Zona B'),
  ];

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async => const [
    RegionPoint(latitude: -21, longitude: -47, zoneId: 'zone-a'),
    RegionPoint(latitude: -21, longitude: -47.1, zoneId: 'zone-a'),
    RegionPoint(latitude: -21.1, longitude: -47.1, zoneId: 'zone-a'),
    RegionPoint(latitude: -21.1, longitude: -47, zoneId: 'zone-a'),
  ];
}

class _NoLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}
