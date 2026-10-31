import 'dart:async';
import 'dart:collection';

import '../../features/farm/data/datasources/farm_remote_data_source.dart';
import '../../features/operations/data/inspection_local_store.dart';
import '../../features/operations/data/inspection_remote_data_source.dart';
import '../../features/operations/data/activity_remote_data_source.dart';
import '../../features/operations/domain/activity_models.dart';
import '../../features/operations/domain/inspection_models.dart';
import '../ui/app_loading_controller.dart';
import '../diagnostics/runtime_diagnostics.dart';

/// Coordinates persistent cache-first reads shared by the app's features.
class SharedReadRepository {
  SharedReadRepository({
    required this.localStore,
    required this.farmRemoteDataSource,
    required this.inspectionRemoteDataSource,
    this.activityRemoteDataSource,
    this.loadingController,
    this.remoteRequestTimeout = const Duration(seconds: 30),
    this.plantPageSize = 1000,
    this.inputPageSize = 1000,
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
  final ActivityRemoteDataSource? activityRemoteDataSource;
  final AppLoadingController? loadingController;
  final Duration remoteRequestTimeout;
  final int plantPageSize;
  final int inputPageSize;
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
    return refreshFarmBoundaryRows();
  }

  Future<List<Map<String, dynamic>>> refreshFarmBoundaryRows() {
    return _singleFlight(
      'farm',
      () => _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchFarmBoundaryRows();
        await localStore.replaceFarmRows(remote);
        return (await localStore.readFarmRows())!;
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getZoneRows() async {
    final local = await localStore.readZoneRows();
    if (local != null) return local;
    return refreshZoneRows();
  }

  Future<List<Map<String, dynamic>>> refreshZoneRows() {
    return _singleFlight(
      'zones',
      () => _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchZonesRows();
        await localStore.replaceZoneRows(remote);
        return (await localStore.readZoneRows())!;
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getRegionRows(String zoneId) async {
    final local = await localStore.readRegionRows(zoneId);
    if (local != null) return local;
    return refreshRegionRows(zoneId);
  }

  Future<List<Map<String, dynamic>>> refreshRegionRows(String zoneId) {
    final key = 'regions:$zoneId';
    return _singleFlight(
      key,
      () => _trackRemote(() async {
        final remote = await farmRemoteDataSource.fetchRegionsRows(zoneId);
        await localStore.replaceRegionRows(zoneId, remote);
        return (await localStore.readRegionRows(zoneId))!;
      }),
    );
  }

  Future<List<OccurrenceType>> getOccurrenceTypes() async {
    final local = await localStore.readCachedCatalog();
    if (local != null) return local;
    return refreshOccurrenceTypes();
  }

  Future<List<OccurrenceType>> refreshOccurrenceTypes() {
    return _singleFlight(
      'occurrence_types',
      () => _trackRemote(() async {
        final remote = await inspectionRemoteDataSource.fetchOccurrenceTypes();
        await localStore.saveCatalog(remote);
        return (await localStore.readCachedCatalog())!;
      }),
    );
  }

  Future<List<FieldInputCatalogItem>> getInputs() async {
    final local = await localStore.readCachedInputs();
    if (local != null) return local;
    return refreshInputs();
  }

  Future<List<FieldInputCatalogItem>> refreshInputs() => _singleFlight(
    'inputs',
    () => _trackRemote(() async {
      final remote = await _fetchAllInputs();
      await localStore.replaceInputs(remote);
      return (await localStore.readCachedInputs())!;
    }),
  );

  Future<List<MixtureCatalogItem>> getMixtures() async {
    final local = await localStore.readCachedMixtures();
    if (local != null) return local;
    return refreshMixtures();
  }

  Future<List<MixtureCatalogItem>> refreshMixtures() => _singleFlight(
    'mixtures',
    () => _trackRemote(() async {
      final remote = await _fetchAllMixtures();
      await localStore.replaceMixtures(remote);
      return (await localStore.readCachedMixtures())!;
    }),
  );

  Future<List<MachineCatalogItem>> getMachines() async {
    final local = await localStore.readCachedMachines();
    if (local != null) return local;
    return refreshMachines();
  }

  Future<List<MachineCatalogItem>> refreshMachines() => _singleFlight(
    'machines',
    () => _trackRemote(() async {
      final remote = await _fetchAllMachines();
      await localStore.replaceMachines(remote);
      return (await localStore.readCachedMachines())!;
    }),
  );

  Future<void> refreshActivityCache() => _singleFlight(
    'refresh_activity',
    () => _refreshCacheAtomically(includeMixtures: true, includeMachines: true),
  );

  /// Carrega os dados remotamente e atualiza o cache local (banco SQLite).
  Future<void> refreshCache() =>
      _singleFlight('refresh_all', _refreshCacheAtomically);

  Future<void> _refreshCacheAtomically({
    bool includeInputs = false,
    bool includeMixtures = false,
    bool includeMachines = false,
  }) async {
    if (_disposed) throw StateError('Cache compartilhado encerrado');
    final controller = loadingController;
    Future<void> action() async {
      final loadedAt = _clock().toUtc();
      final farmFuture = _remoteRead(
        farmRemoteDataSource.fetchFarmBoundaryRows,
      );
      final zonesFuture = _remoteRead(farmRemoteDataSource.fetchZonesRows);
      final catalogFuture = _remoteRead(
        inspectionRemoteDataSource.fetchOccurrenceTypes,
      );
      final plantsFuture = _fetchAllPlantRows();
      final inputsFuture = includeInputs ? _fetchAllInputs() : null;
      final mixturesFuture = includeMixtures ? _fetchAllMixtures() : null;
      final machinesFuture = includeMachines ? _fetchAllMachines() : null;

      final resolved = await Future.wait<dynamic>([
        farmFuture,
        zonesFuture,
        catalogFuture,
        plantsFuture,
        ?inputsFuture,
        ?mixturesFuture,
        ?machinesFuture,
      ]);
      final farmRows = resolved[0] as List<Map<String, dynamic>>;
      final zoneRows = resolved[1] as List<Map<String, dynamic>>;
      final occurrenceTypes = resolved[2] as List<OccurrenceType>;
      final plantRows = resolved[3] as List<Map<String, dynamic>>;
      final inputs = includeInputs
          ? resolved[4] as List<FieldInputCatalogItem>
          : null;
      final mixturesIndex = 4 + (includeInputs ? 1 : 0);
      final mixtures = includeMixtures
          ? resolved[mixturesIndex] as List<MixtureCatalogItem>
          : null;
      final machinesIndex = mixturesIndex + (includeMixtures ? 1 : 0);
      final machines = includeMachines
          ? resolved[machinesIndex] as List<MachineCatalogItem>
          : null;
      final regionEntries = await Future.wait(
        zoneRows.map((zone) async {
          final id = zone['id'];
          if (id is! String || id.isEmpty) {
            throw const FormatException('Zona remota sem identificador válido');
          }
          final rows = await _remoteRead(
            () => farmRemoteDataSource.fetchRegionsRows(id),
          );
          return MapEntry(id, rows);
        }),
      );
      final eligibleIds = plantRows
          .where((row) => row['non_existent'] != true)
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      final openOccurrences = eligibleIds.isEmpty
          ? <String, Set<String>>{}
          : await _remoteRead(
              () =>
                  inspectionRemoteDataSource.fetchOpenOccurrences(eligibleIds),
            );

      await localStore.replaceSharedCache(
        farmRows: farmRows,
        zoneRows: zoneRows,
        regionRowsByZone: Map.fromEntries(regionEntries),
        plantRows: plantRows,
        openOccurrences: openOccurrences,
        occurrenceTypes: occurrenceTypes,
        inputs: inputs,
        mixtures: mixtures,
        machines: machines,
        loadedAt: loadedAt,
      );
    }

    if (controller == null) return action();
    await controller.track(action);
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlantRows() async {
    final rows = <Map<String, dynamic>>[];
    final seenIds = <Object>{};
    var from = 0;
    while (true) {
      final page = await _remoteRead(
        () => farmRemoteDataSource.fetchPlantRowsPage(
          from: from,
          to: from + plantPageSize - 1,
        ),
      );
      if (page.isEmpty) return rows;
      for (final row in page) {
        final id = row['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('Planta remota sem identificador válido');
        }
        if (!seenIds.add(id)) {
          throw StateError('Página remota repetiu o registro "$id".');
        }
      }
      rows.addAll(page);
      from += page.length;
    }
  }

  Future<List<FieldInputCatalogItem>> _fetchAllInputs() async {
    final remote = activityRemoteDataSource;
    if (remote == null) {
      throw StateError('Origem remota de insumos não configurada');
    }
    final items = <FieldInputCatalogItem>[];
    final seenIds = <String>{};
    var from = 0;
    while (true) {
      final page = await _remoteRead(
        () => remote.fetchInputPage(from: from, to: from + inputPageSize - 1),
      );
      if (page.isEmpty) return items;
      for (final row in page) {
        final item = FieldInputCatalogItem.fromJson(row);
        if (!seenIds.add(item.id)) {
          throw StateError('Página remota repetiu o insumo "${item.id}".');
        }
        items.add(item);
      }
      from += page.length;
    }
  }

  Future<List<MixtureCatalogItem>> _fetchAllMixtures() async {
    final remote = activityRemoteDataSource;
    if (remote == null) {
      throw StateError('Origem remota de caldas não configurada');
    }
    final mixtures = <MixtureCatalogItem>[];
    final seenIds = <String>{};
    var from = 0;
    while (true) {
      final page = await _remoteRead(
        () => remote.fetchMixturePage(from: from, to: from + inputPageSize - 1),
      );
      if (page.isEmpty) return mixtures;
      for (final row in page) {
        final mixture = MixtureCatalogItem.fromJson(row);
        if (!seenIds.add(mixture.id)) {
          throw StateError('Página remota repetiu a calda "${mixture.id}".');
        }
        mixtures.add(mixture);
      }
      from += page.length;
    }
  }

  Future<List<MachineCatalogItem>> _fetchAllMachines() async {
    final remote = activityRemoteDataSource;
    if (remote == null) {
      throw StateError('Origem remota de máquinas não configurada');
    }
    final machines = <MachineCatalogItem>[];
    final seenIds = <String>{};
    var from = 0;
    while (true) {
      final page = await _remoteRead(
        () => remote.fetchMachinePage(from: from, to: from + inputPageSize - 1),
      );
      if (page.isEmpty) return machines;
      for (final row in page) {
        final machine = MachineCatalogItem.fromJson(row);
        if (!seenIds.add(machine.id)) {
          throw StateError('Página remota repetiu a máquina "${machine.id}".');
        }
        machines.add(machine);
      }
      from += page.length;
    }
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
