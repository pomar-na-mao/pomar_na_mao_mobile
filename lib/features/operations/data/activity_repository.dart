import 'dart:async';

import '../../../core/data/shared_read_repository.dart';
import '../domain/activity_models.dart';
import '../domain/inspection_models.dart';
import 'activity_local_store.dart';
import 'activity_remote_data_source.dart';

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.plants,
    this.mixtures = const [],
    this.machines = const [],
    this.inputs = const [],
  });

  final List<InspectionPlant> plants;
  final List<MixtureCatalogItem> mixtures;
  final List<MachineCatalogItem> machines;
  final List<FieldInputCatalogItem> inputs;
}

abstract interface class ActivityRepository {
  String createLocalId();
  Future<ActivitySnapshot> loadSnapshot({bool forceRemote = false});
  Future<ActivityEntry> save({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
    List<ActivityInput> inputs = const [],
  });
  Future<List<ActivityEntry>> list();
  Future<bool> deleteLocal(String localId);
  Future<bool> syncOne(String localId);
  Future<bool> syncAll();
}

class DefaultActivityRepository implements ActivityRepository {
  DefaultActivityRepository({
    required this.localStore,
    required this.remoteDataSource,
    required this.sharedReadRepository,
  });

  final ActivityLocalStore localStore;
  final ActivityRemoteDataSource remoteDataSource;
  final SharedReadRepository sharedReadRepository;
  Future<bool>? _syncFlight;

  @override
  String createLocalId() => localStore.createLocalId();

  @override
  Future<ActivitySnapshot> loadSnapshot({bool forceRemote = false}) async {
    if (forceRemote) {
      await sharedReadRepository.refreshActivityCache();
    }
    final plants = await sharedReadRepository.getPlantRows();
    final mixtures = await sharedReadRepository.getMixtures();
    final machines = await sharedReadRepository.getMachines();
    return ActivitySnapshot(
      plants: plants
          .map(InspectionPlant.fromJson)
          .where((plant) => plant.hasValidCoordinates && !plant.nonExistent)
          .toList(growable: false),
      mixtures: mixtures,
      machines: machines,
    );
  }

  @override
  Future<ActivityEntry> save({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
    List<ActivityInput> inputs = const [],
  }) => localStore.create(
    geometry: geometry,
    activity: activity,
    performedAt: performedAt,
    responsible: responsible,
    mixture: mixture,
    machine: machine,
    inputs: inputs,
  );

  @override
  Future<List<ActivityEntry>> list() => localStore.list();

  @override
  Future<bool> deleteLocal(String localId) => localStore.delete(localId);

  @override
  Future<bool> syncOne(String localId) async {
    final entry = await localStore.find(localId);
    if (entry == null || entry.syncStatus == ActivitySyncStatus.synced) {
      return true;
    }
    return _sync([entry]);
  }

  @override
  Future<bool> syncAll() {
    final existing = _syncFlight;
    if (existing != null) return existing;
    final flight = _syncAllPending();
    _syncFlight = flight;
    return flight.whenComplete(() {
      if (identical(_syncFlight, flight)) _syncFlight = null;
    });
  }

  Future<bool> _syncAllPending() async =>
      _sync(await localStore.listSyncable());

  Future<bool> _sync(List<ActivityEntry> entries) async {
    if (entries.isEmpty) return true;
    final ids = entries.map((entry) => entry.localId).toList();
    await localStore.markSyncing(ids);
    try {
      final results = await remoteDataSource.syncEntries({
        'deviceId': await localStore.database.deviceId,
        'entries': entries.map((entry) => entry.toPayload()).toList(),
      });
      final byId = {for (final result in results) result.localId: result};
      for (final entry in entries) {
        final result = byId[entry.localId];
        if (result == null) {
          await localStore.markError([
            entry.localId,
          ], 'Resposta remota incompleta');
        } else {
          await localStore.markSynced(result);
        }
      }
      return byId.length == entries.length;
    } catch (error) {
      await localStore.markError(ids, error);
      return false;
    }
  }
}
