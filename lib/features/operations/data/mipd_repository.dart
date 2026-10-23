import '../domain/inspection_models.dart';
import '../domain/mipd_models.dart';
import 'inspection_local_store.dart';
import 'mipd_local_store.dart';
import 'mipd_remote_data_source.dart';

class MipdSnapshot {
  const MipdSnapshot({required this.plants, required this.types});
  final List<InspectionPlant> plants;
  final List<OccurrenceType> types;
}

abstract interface class MipdRepository {
  String createLocalId();
  Future<MipdSnapshot?> loadSnapshot({bool forceRemote = false});
  Future<MipdMarking> save({
    required String localId,
    required String plantId,
    required OccurrenceType occurrenceType,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
  });
  Future<List<MipdMarking>> list();
  Future<bool> syncOne(String localId);
  Future<bool> syncAll();
}

class DefaultMipdRepository implements MipdRepository {
  DefaultMipdRepository({
    required this.localStore,
    required this.remoteDataSource,
    required this.inspectionLocalStore,
    required this.refreshSharedCache,
  });

  final MipdLocalStore localStore;
  final MipdRemoteDataSource remoteDataSource;
  final InspectionLocalStore inspectionLocalStore;
  final Future<void> Function() refreshSharedCache;
  Future<bool>? _syncFlight;

  @override
  String createLocalId() => localStore.createLocalId();

  @override
  Future<MipdSnapshot?> loadSnapshot({bool forceRemote = false}) async {
    if (forceRemote) await refreshSharedCache();
    final snapshot = await inspectionLocalStore.readSnapshot();
    if (snapshot == null) return null;
    return MipdSnapshot(
      plants: snapshot.plants,
      types: snapshot.types.where((type) => type.isPestDisease).toList(),
    );
  }

  @override
  Future<MipdMarking> save({
    required String localId,
    required String plantId,
    required OccurrenceType occurrenceType,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
  }) {
    validatePestDiseaseType(occurrenceType);
    return localStore.create(
      localId: localId,
      plantId: plantId,
      occurrenceTypeId: occurrenceType.id,
      plantParts: plantParts,
      localPhotoPath: localPhotoPath,
    );
  }

  @override
  Future<List<MipdMarking>> list() => localStore.list();

  @override
  Future<bool> syncOne(String localId) async {
    final marking = await localStore.find(localId);
    if (marking == null || marking.status == MipdSyncStatus.synced) return true;
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

  Future<bool> _sync(List<MipdMarking> markings) async {
    if (markings.isEmpty) return true;
    final deviceId = await localStore.deviceId;
    final ready = <MipdMarking>[];
    for (var marking in markings) {
      await localStore.markSyncing([marking.localId]);
      try {
        if (marking.localPhotoPath != null && marking.remotePhotoPath == null) {
          final remotePath = await remoteDataSource.uploadPhoto(
            deviceId: deviceId,
            localId: marking.localId,
            localPath: marking.localPhotoPath!,
          );
          await localStore.setRemotePhotoPath(marking.localId, remotePath);
          marking = marking.copyWith(remotePhotoPath: remotePath);
        }
        ready.add(marking);
      } catch (error) {
        await localStore.markError([marking.localId], error.toString());
      }
    }
    if (ready.isEmpty) return false;
    try {
      final results = await remoteDataSource.syncMarkings({
        'deviceId': deviceId,
        'markings': ready.map((marking) => marking.toPayload()).toList(),
      });
      final byId = {
        for (final result in results) result.localMarkingId: result,
      };
      for (final marking in ready) {
        final result = byId[marking.localId];
        if (result == null) {
          await localStore.markError([
            marking.localId,
          ], 'Resposta remota incompleta');
        } else {
          await localStore.markSynced(result);
        }
      }
      return byId.length == ready.length && ready.length == markings.length;
    } catch (error) {
      await localStore.markError(
        ready.map((item) => item.localId),
        error.toString(),
      );
      return false;
    }
  }
}
