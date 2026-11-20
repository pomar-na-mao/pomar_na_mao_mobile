import '../domain/harvest_forecast_models.dart';
import '../domain/inspection_models.dart';
import 'harvest_forecast_local_store.dart';
import 'harvest_forecast_remote_data_source.dart';
import 'inspection_local_store.dart';

abstract interface class HarvestForecastRepository {
  String createLocalId();
  Future<List<InspectionPlant>> loadPlants({bool forceRemote = false});
  Future<HarvestForecastMarking> save({
    String? localId,
    required double latitude,
    required double longitude,
    required HarvestForecastClassification classification,
    DateTime? createdAt,
  });
  Future<List<HarvestForecastMarking>> list();
  Future<HarvestForecastMarking?> updateClassification({
    required String localId,
    required HarvestForecastClassification classification,
  });
  Future<bool> delete(String localId);
  Future<bool> syncOne(String localId);
  Future<bool> syncAll();
}

class DefaultHarvestForecastRepository implements HarvestForecastRepository {
  DefaultHarvestForecastRepository({
    required this.localStore,
    required this.remoteDataSource,
    required this.inspectionLocalStore,
    required this.refreshSharedCache,
  });

  final HarvestForecastLocalStore localStore;
  final HarvestForecastRemoteDataSource remoteDataSource;
  final InspectionLocalStore inspectionLocalStore;
  final Future<void> Function() refreshSharedCache;
  Future<bool>? _syncFlight;

  @override
  String createLocalId() => localStore.createLocalId();

  @override
  Future<List<InspectionPlant>> loadPlants({bool forceRemote = false}) async {
    if (forceRemote) await refreshSharedCache();
    final snapshot = await inspectionLocalStore.readSnapshot();
    return snapshot?.plants ?? const [];
  }

  @override
  Future<HarvestForecastMarking> save({
    String? localId,
    required double latitude,
    required double longitude,
    required HarvestForecastClassification classification,
    DateTime? createdAt,
  }) => localStore.create(
    localId: localId,
    latitude: latitude,
    longitude: longitude,
    classification: classification,
    createdAt: createdAt,
  );

  @override
  Future<List<HarvestForecastMarking>> list() => localStore.list();

  @override
  Future<HarvestForecastMarking?> updateClassification({
    required String localId,
    required HarvestForecastClassification classification,
  }) => localStore.updateClassification(localId, classification);

  @override
  Future<bool> delete(String localId) => localStore.delete(localId);

  @override
  Future<bool> syncOne(String localId) async {
    final marking = await localStore.find(localId);
    if (marking == null || marking.status == HarvestForecastSyncStatus.synced) {
      return true;
    }
    return _sync([marking]);
  }

  @override
  Future<bool> syncAll() async {
    if (_syncFlight != null) return _syncFlight!;
    final flight = _sync(await localStore.listSyncable());
    _syncFlight = flight;
    try {
      return await flight;
    } finally {
      _syncFlight = null;
    }
  }

  Future<bool> _sync(List<HarvestForecastMarking> markings) async {
    if (markings.isEmpty) return true;
    final deviceId = await localStore.deviceId;
    final ids = markings.map((item) => item.localId).toList(growable: false);
    await localStore.markSyncing(ids);
    try {
      final results = await remoteDataSource.syncMarkings({
        'deviceId': deviceId,
        'markings': markings.map((marking) => marking.toPayload()).toList(),
      });
      final byId = {
        for (final result in results) result.localMarkingId: result,
      };
      for (final marking in markings) {
        final result = byId[marking.localId];
        if (result == null) {
          await localStore.markError(
            [marking.localId],
            'Resposta remota incompleta',
          );
        } else {
          await localStore.markSynced(result);
        }
      }
      return byId.length == markings.length;
    } catch (error) {
      await localStore.markError(ids, error.toString());
      return false;
    }
  }
}
