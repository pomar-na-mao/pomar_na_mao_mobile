import 'dart:async';
import 'dart:collection';

import '../../features/farm/data/datasources/farm_remote_data_source.dart';
import '../../features/operations/data/inspection_local_store.dart';
import '../../features/operations/data/inspection_remote_data_source.dart';
import '../../features/operations/domain/inspection_models.dart';
import '../ui/app_loading_controller.dart';
import '../diagnostics/runtime_diagnostics.dart';

/// Coordinates persistent cache-first reads shared by the app's features.
class SharedReadRepository {
  SharedReadRepository({
    required this.localStore,
    required this.farmRemoteDataSource,
    required this.inspectionRemoteDataSource,
    this.loadingController,
    this.remoteRequestTimeout = const Duration(seconds: 30),
    this.plantPageSize = 1000,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _revisionSubscription = localStore.database.changes.listen((_) {
      _cachedPlants = null;
      if (!_plantChanges.isClosed) _plantChanges.add(null);
    });
  }

  final InspectionLocalStore localStore;
  final FarmRemoteDataSource farmRemoteDataSource;
  final InspectionRemoteDataSource inspectionRemoteDataSource;
  final AppLoadingController? loadingController;
  final Duration remoteRequestTimeout;
  final int plantPageSize;
  final DateTime Function() _clock;

  final Map<String, Future<dynamic>> _inFlight = {};
  final _remoteLimiter = _AsyncSemaphore(2);
  final StreamController<void> _plantChanges = StreamController<void>.broadcast(
    sync: true,
  );
  bool _disposed = false;
  StreamSubscription<int>? _revisionSubscription;
  List<Map<String, dynamic>>? _cachedPlants;
  int _cachedRevision = -1;
  int _plantLoadGeneration = 0;

  Stream<void> get plantChanges => _plantChanges.stream;

  Future<List<Map<String, dynamic>>> getPlantRows() async {
    if (_disposed) throw StateError('Cache compartilhado encerrado');
    final revision = localStore.database.revision;
    if (_cachedPlants != null && _cachedRevision == revision) {
      return _cachedPlants!;
    }
    final local = await _singleFlight('hydrate:$revision', () async {
      final rows = await localStore.readSharedPlantRows();
      if (rows != null &&
          localStore.database.revision == revision &&
          !_disposed) {
        _cachedRevision = revision;
        _cachedPlants = List.unmodifiable(
          rows.map(Map<String, dynamic>.unmodifiable),
        );
      }
      return rows;
    });
    if (revision != localStore.database.revision) return getPlantRows();
    if (local != null) return _cachedPlants ?? local;
    return _singleFlight('plants', _fetchAndPersistPlants);
  }

  Future<List<Map<String, dynamic>>> refreshPlantRows() =>
      _singleFlight('plants', _fetchAndPersistPlants);

  Future<CachedPlantTotals> getPlantTotals() async {
    if (_disposed) throw StateError('Cache compartilhado encerrado');
    final local = await localStore.readSharedPlantTotals();
    if (local != null) return local;
    await getPlantRows();
    final hydrated = await localStore.readSharedPlantTotals();
    if (hydrated != null) return hydrated;
    throw StateError('Totais de plantas indisponiveis');
  }

  Future<List<Map<String, dynamic>>> _fetchAndPersistPlants() {
    final controller = loadingController;
    if (controller == null) return _fetchAndPersistPlantsUnchecked();
    return controller.track(_fetchAndPersistPlantsUnchecked);
  }

  Future<List<Map<String, dynamic>>> _fetchAndPersistPlantsUnchecked() async {
    final token = ++_plantLoadGeneration;
    final loadedAt = _clock().toUtc();
    String? generationId;
    try {
      generationId = await localStore.beginPlantStaging(loadedAt: loadedAt);
      final eligibleIds = <String>[];
      var from = 0;
      final seenIds = <Object>{};
      while (true) {
        _ensureCurrentPlantLoad(token);
        final rows = await _remoteRead(
          () => farmRemoteDataSource.fetchPlantRowsPage(
            from: from,
            to: from + plantPageSize - 1,
          ),
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          final id = row['id'];
          if (id is! String || id.isEmpty) {
            throw const FormatException(
              'Planta remota sem identificador valido',
            );
          }
          if (!seenIds.add(id)) {
            throw StateError('Pagina remota repetiu o registro "$id".');
          }
          if (row['non_existent'] != true) eligibleIds.add(id);
        }
        await localStore.appendStagedPlantRows(generationId, rows);
        from += rows.length;
      }

      _ensureCurrentPlantLoad(token);
      final openOccurrences = eligibleIds.isEmpty
          ? <String, Set<String>>{}
          : await RuntimeDiagnostics.instance.track(
              RuntimeStage.occurrences,
              () => _remoteRead(
                () => inspectionRemoteDataSource.fetchOpenOccurrences(
                  eligibleIds,
                ),
              ),
            );
      _ensureCurrentPlantLoad(token);
      if (openOccurrences.isNotEmpty) {
        await localStore.applyOpenOccurrencesToStaging(
          generationId,
          openOccurrences,
        );
      }
      _ensureCurrentPlantLoad(token);
      await localStore.publishPlantStaging(generationId);
      return await getPlantRows();
    } catch (_) {
      if (generationId != null) {
        await localStore.discardPlantStaging(generationId);
      }
      rethrow;
    }
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
    if (controller == null) return _remoteRead(action);
    return controller.track(() => _remoteRead(action));
  }

  Future<T> _remoteRead<T>(Future<T> Function() action) =>
      _remoteLimiter.run(() => action().timeout(remoteRequestTimeout));

  void _ensureCurrentPlantLoad(int token) {
    if (_disposed || token != _plantLoadGeneration) {
      throw StateError('Carga de plantas obsoleta');
    }
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
    _cachedPlants = null;
    await _revisionSubscription?.cancel();
    await _plantChanges.close();
  }
}

class _AsyncSemaphore {
  _AsyncSemaphore(this._max);

  final int _max;
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < _max) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release() {
    final waiter = _waiters.isEmpty ? null : _waiters.removeFirst();
    if (waiter == null) {
      _active--;
      return;
    }
    waiter.complete();
  }
}
