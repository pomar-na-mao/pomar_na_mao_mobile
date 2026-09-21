import 'dart:async';

import '../../../core/data/shared_read_repository.dart';
import '../../../core/ui/app_loading_controller.dart';
import '../../farm/domain/user_location.dart';
import '../domain/inspection_models.dart';
import 'inspection_local_store.dart';
import 'inspection_remote_data_source.dart';

abstract interface class InspectionRepository {
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false});
  Future<List<OccurrenceType>> getCatalog();
  Future<void> togglePlantOccurrence(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  });
  Future<LocalInspection?> finalizeInspection();
  Future<bool> syncPending();
  Future<List<LocalInspection>> listLocalInspections();
  Future<List<InspectionChange>> getInspectionChanges(String inspectionId);
  Future<void> removePlantFromInspection(String inspectionId, String plantId);
}

class DefaultInspectionRepository implements InspectionRepository {
  DefaultInspectionRepository({
    required this.localStore,
    required this.remoteDataSource,
    this.sharedReadRepository,
    this.loadingController,
  });

  final InspectionLocalStore localStore;
  final InspectionRemoteDataSource remoteDataSource;
  final SharedReadRepository? sharedReadRepository;
  final AppLoadingController? loadingController;

  Completer<bool>? _currentSync;

  @override
  Future<InspectionSnapshot?> loadSnapshot({bool forceRemote = false}) async {
    final local = await localStore.readSnapshot();
    final shared = sharedReadRepository;
    if (shared != null) {
      if (!forceRemote) {
        if (local != null && local.types.isEmpty) {
          try {
            await shared.getOccurrenceTypes();
            return await localStore.readSnapshot();
          } catch (_) {
            return local;
          }
        }
        return local;
      }

      final catalog = await shared.getOccurrenceTypes();
      if (catalog.isEmpty) {
        throw StateError(
          'Catálogo indisponível. Verifique o acesso e carregue novamente.',
        );
      }
      await shared.refreshPlantRows();
      return await localStore.readSnapshot();
    }

    if (!forceRemote && local != null) {
      return local;
    }

    try {
      final controller = loadingController;
      final remote = await (controller == null
          ? remoteDataSource.fetchSnapshot()
          : controller.track(remoteDataSource.fetchSnapshot));
      await localStore.replaceSnapshot(remote);
      return await localStore.readSnapshot();
    } catch (e) {
      if (local != null) {
        return local;
      }
      rethrow;
    }
  }

  @override
  Future<List<OccurrenceType>> getCatalog() async {
    final shared = sharedReadRepository;
    if (shared != null) return shared.getOccurrenceTypes();

    final local = await localStore.readCatalog();
    if (local.isNotEmpty) {
      return local;
    }

    try {
      final controller = loadingController;
      final remote = await (controller == null
          ? remoteDataSource.fetchOccurrenceTypes()
          : controller.track(remoteDataSource.fetchOccurrenceTypes));
      await localStore.saveCatalog(remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<void> togglePlantOccurrence(
    String plantId,
    String typeId, {
    UserLocation? location,
    double? distance,
  }) {
    return localStore.toggle(
      plantId,
      typeId,
      location: location,
      distance: distance,
    );
  }

  @override
  Future<LocalInspection?> finalizeInspection() async {
    final finalized = await localStore.finalize();
    if (finalized != null) {
      // Fire and forget or schedule sync in serial queue
      unawaited(syncPending());
    }
    return finalized;
  }

  @override
  Future<bool> syncPending() async {
    if (_currentSync != null) {
      return _currentSync!.future;
    }

    final completer = Completer<bool>();
    _currentSync = completer;

    try {
      final pending = await localStore.pending();
      if (pending.isEmpty) {
        completer.complete(true);
        return true;
      }

      for (final inspection in pending) {
        await localStore.markSyncing(inspection.id);
      }

      final primary = pending.first;
      final allPendingIds = pending.map((i) => i.id).toList();

      final groupedPlants = <String, List<Map<String, dynamic>>>{};
      DateTime? earliestStartedAt;
      DateTime? latestFinishedAt;

      for (final inspection in pending) {
        if (earliestStartedAt == null ||
            inspection.startedAt.isBefore(earliestStartedAt)) {
          earliestStartedAt = inspection.startedAt;
        }
        final finished = inspection.finishedAt ?? inspection.startedAt;
        if (latestFinishedAt == null || finished.isAfter(latestFinishedAt)) {
          latestFinishedAt = finished;
        }

        final payload = inspection.payload;
        final plantsList = (payload['plantsChanged'] as List<dynamic>? ?? []);
        for (final p in plantsList) {
          final map = Map<String, dynamic>.from(p as Map);
          final plantId = map['plantId'] as String;
          final changes = (map['changes'] as List<dynamic>? ?? [])
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          (groupedPlants[plantId] ??= []).addAll(changes);
        }
      }

      final mergedPlantsChanged = [
        for (final entry in groupedPlants.entries)
          {'plantId': entry.key, 'changes': entry.value},
      ];

      final mergedPayload = <String, dynamic>{
        'deviceId': primary.payload['deviceId'],
        'localInspectionId': primary.id,
        'startedAt':
            earliestStartedAt?.toIso8601String() ??
            primary.startedAt.toIso8601String(),
        'finishedAt':
            latestFinishedAt?.toIso8601String() ??
            (primary.finishedAt ?? primary.startedAt).toIso8601String(),
        'zoneId': null,
        'occurrenceTypeId': null,
        'plantsChanged': mergedPlantsChanged,
      };

      try {
        final controller = loadingController;
        final result = await (controller == null
            ? remoteDataSource.syncInspection(mergedPayload)
            : controller.track(
                () => remoteDataSource.syncInspection(mergedPayload),
              ));
        await localStore.acknowledgeMerged(
          inspectionIds: allPendingIds,
          result: result,
        );
        completer.complete(true);
        return true;
      } catch (e) {
        for (final id in allPendingIds) {
          await localStore.markError(id, e);
        }
        completer.complete(false);
        return false;
      }
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _currentSync = null;
    }
  }

  @override
  Future<List<LocalInspection>> listLocalInspections() {
    return localStore.list();
  }

  @override
  Future<List<InspectionChange>> getInspectionChanges(String inspectionId) {
    return localStore.changes(inspectionId);
  }

  @override
  Future<void> removePlantFromInspection(String inspectionId, String plantId) {
    return localStore.removePlantFromInspection(inspectionId, plantId);
  }
}
