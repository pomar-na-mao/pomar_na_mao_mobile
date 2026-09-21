import 'dart:async';

import '../../features/farm/data/datasources/farm_remote_data_source.dart';
import '../../features/operations/data/inspection_local_store.dart';
import '../../features/operations/data/inspection_remote_data_source.dart';
import '../../features/operations/domain/inspection_models.dart';
import '../ui/app_loading_controller.dart';

/// Coordinates persistent cache-first reads shared by the app's features.
class SharedReadRepository {
  SharedReadRepository({
    required this.localStore,
    required this.farmRemoteDataSource,
    required this.inspectionRemoteDataSource,
    this.loadingController,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final InspectionLocalStore localStore;
  final FarmRemoteDataSource farmRemoteDataSource;
  final InspectionRemoteDataSource inspectionRemoteDataSource;
  final AppLoadingController? loadingController;
  final DateTime Function() _clock;

  final Map<String, Future<dynamic>> _inFlight = {};
  final StreamController<void> _plantChanges = StreamController<void>.broadcast(
    sync: true,
  );
  bool _disposed = false;

  Stream<void> get plantChanges => _plantChanges.stream;

  Future<List<Map<String, dynamic>>> getPlantRows() async {
    final local = await localStore.readSharedPlantRows();
    if (local != null) return local;
    return _singleFlight('plants', () async {
      final cached = await localStore.readSharedPlantRows();
      if (cached != null) return cached;
      return _fetchAndPersistPlants();
    });
  }

  Future<List<Map<String, dynamic>>> refreshPlantRows() =>
      _singleFlight('plants', _fetchAndPersistPlants);

  Future<List<Map<String, dynamic>>> _fetchAndPersistPlants() {
    final controller = loadingController;
    if (controller == null) return _fetchAndPersistPlantsUnchecked();
    return controller.track(_fetchAndPersistPlantsUnchecked);
  }

  Future<List<Map<String, dynamic>>> _fetchAndPersistPlantsUnchecked() async {
    final rows = await farmRemoteDataSource.fetchPlantsRows();
    final eligibleIds = rows
        .where((row) => row['non_existent'] != true)
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
    final openOccurrences = eligibleIds.isEmpty
        ? <String, Set<String>>{}
        : await inspectionRemoteDataSource.fetchOpenOccurrences(eligibleIds);

    await localStore.replaceSharedPlantRows(
      rows,
      openOccurrences,
      loadedAt: _clock().toUtc(),
    );
    final persisted = await localStore.readSharedPlantRows();
    if (persisted == null) {
      throw StateError('Cache de plantas não foi persistido');
    }
    if (!_plantChanges.isClosed) _plantChanges.add(null);
    return persisted;
  }

  Future<List<Map<String, dynamic>>> getFarmBoundaryRows() async {
    final local = await localStore.readFarmRows();
    if (local != null) return local;
    return _singleFlight('farm', () async {
      final cached = await localStore.readFarmRows();
      if (cached != null) return cached;
      return _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchFarmBoundaryRows();
        await localStore.replaceFarmRows(remote);
        return (await localStore.readFarmRows())!;
      });
    });
  }

  Future<List<Map<String, dynamic>>> getZoneRows() async {
    final local = await localStore.readZoneRows();
    if (local != null) return local;
    return _singleFlight('zones', () async {
      final cached = await localStore.readZoneRows();
      if (cached != null) return cached;
      return _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchZonesRows();
        await localStore.replaceZoneRows(remote);
        return (await localStore.readZoneRows())!;
      });
    });
  }

  Future<List<Map<String, dynamic>>> getRegionRows(String zoneId) async {
    final local = await localStore.readRegionRows(zoneId);
    if (local != null) return local;
    final key = 'regions:$zoneId';
    return _singleFlight(key, () async {
      final cached = await localStore.readRegionRows(zoneId);
      if (cached != null) return cached;
      return _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchRegionsRows(zoneId);
        await localStore.replaceRegionRows(zoneId, remote);
        return (await localStore.readRegionRows(zoneId))!;
      });
    });
  }

  Future<List<OccurrenceType>> getOccurrenceTypes() async {
    final local = await localStore.readCachedCatalog();
    if (local != null) return local;
    return _singleFlight('occurrence_types', () async {
      final cached = await localStore.readCachedCatalog();
      if (cached != null) return cached;
      return _trackRemote(() async {
        final remote = await inspectionRemoteDataSource.fetchOccurrenceTypes();
        await localStore.saveCatalog(remote);
        return (await localStore.readCachedCatalog())!;
      });
    });
  }

  Future<T> _trackRemote<T>(Future<T> Function() action) {
    final controller = loadingController;
    if (controller == null) return action();
    return controller.track(action);
  }

  Future<T> _singleFlight<T>(String key, Future<T> Function() load) {
    if (_disposed) {
      return Future<T>.error(StateError('Cache compartilhado encerrado'));
    }
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    late final Future<T> future;
    future = load().whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _plantChanges.close();
  }
}
