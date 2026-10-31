import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../farm/domain/region_point.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/domain/user_position_tracker.dart';
import '../../farm/domain/zone.dart';
import '../../farm/domain/zones_repository.dart';
import '../data/activity_repository.dart';
import '../domain/activity_models.dart';
import '../domain/inspection_models.dart';

enum ActivityLoadStatus { initial, loading, success, empty, error }

class ActivityViewModel extends ChangeNotifier {
  ActivityViewModel({
    required this.repository,
    required this.locationService,
    this.zonesRepository,
  });

  final ActivityRepository repository;
  final LocationService locationService;
  final ZonesRepository? zonesRepository;
  final ActivityGeometryBuilder drawing = ActivityGeometryBuilder();
  final UserPositionTracker _positionTracker = UserPositionTracker();

  List<InspectionPlant> _allPlants = const [];
  List<InspectionPlant> _filteredPlants = const [];
  List<InspectionPlant> get allPlants => _allPlants;
  List<InspectionPlant> get plants =>
      _selectedZoneFilterId == null ? _allPlants : _filteredPlants;

  List<Zone> _zones = const [];
  List<Zone> get zones => _zones;
  String? _selectedZoneFilterId;
  String? get selectedZoneFilterId => _selectedZoneFilterId;
  List<RegionPoint> _selectedZonePoints = const [];
  List<RegionPoint> get selectedZonePoints => _selectedZonePoints;
  final Map<String, List<RegionPoint>> _zoneRegionsCache = {};
  bool get isFiltered => _selectedZoneFilterId != null;
  Zone? get selectedZone {
    final selectedId = _selectedZoneFilterId;
    if (selectedId == null) return null;
    for (final zone in _zones) {
      if (zone.id == selectedId) return zone;
    }
    return null;
  }

  List<MixtureCatalogItem> mixtures = const [];
  List<MachineCatalogItem> machines = const [];
  List<FieldInputCatalogItem> catalog = const [];
  List<ActivityEntry> entries = const [];
  ActivityLoadStatus status = ActivityLoadStatus.initial;
  String? errorMessage;
  bool syncing = false;
  bool saving = false;
  bool deleting = false;
  StreamSubscription<LocationResult>? _locationSubscription;
  LocationResult? _locationResult;
  bool _isLocationActive = false;
  bool _disposed = false;

  UserLocation? get userLocation => _locationResult?.location;
  ActivityGeometryType get geometryType => drawing.type;
  List<ActivityPoint> get points => drawing.points;
  ActivityGeometry get geometry => drawing.build();
  String? get geometryError => geometry.validate();

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    await Future.wait([
      loadSnapshot(forceRemote: false),
      loadEntries(),
      loadZones(),
    ]);
  }

  Future<void> loadZones() async {
    final source = zonesRepository;
    if (source == null) return;
    try {
      final loaded = await source.fetchZones();
      _zones = [...loaded]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    } catch (_) {
      // O mapa continua utilizavel mesmo quando o catalogo de zonas falha.
    }
  }

  Future<void> setZoneFilter(String? zoneId) async {
    _selectedZoneFilterId = zoneId;
    _refreshFilteredPlants();
    _selectedZonePoints = zoneId == null
        ? const []
        : _zoneRegionsCache[zoneId] ?? const [];
    notifyListeners();
    if (zoneId == null || _zoneRegionsCache.containsKey(zoneId)) return;

    final source = zonesRepository;
    if (source == null) return;
    try {
      final points = await source.fetchRegionsForZone(zoneId);
      _zoneRegionsCache[zoneId] = points;
      if (_selectedZoneFilterId == zoneId) {
        _selectedZonePoints = points;
        notifyListeners();
      }
    } catch (_) {
      // Mantem o filtro de plantas mesmo sem o contorno para enquadrar no mapa.
    }
  }

  Future<void> loadSnapshot({bool forceRemote = true}) async {
    status = ActivityLoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await repository.loadSnapshot(forceRemote: forceRemote);
      _allPlants = snapshot.plants;
      _refreshFilteredPlants();
      mixtures = snapshot.mixtures;
      machines = snapshot.machines;
      catalog = snapshot.inputs;
      status = _allPlants.isEmpty && mixtures.isEmpty && machines.isEmpty
          ? ActivityLoadStatus.empty
          : ActivityLoadStatus.success;
    } catch (error) {
      errorMessage = error.toString();
      status = ActivityLoadStatus.error;
    }
    notifyListeners();
  }

  void _refreshFilteredPlants() {
    final zoneId = _selectedZoneFilterId;
    _filteredPlants = zoneId == null
        ? const []
        : _allPlants
              .where((plant) => plant.zoneId == zoneId)
              .toList(growable: false);
  }

  bool addPoint(ActivityPoint point) {
    final added = drawing.add(point);
    if (added) notifyListeners();
    return added;
  }

  void undoPoint() {
    drawing.undo();
    notifyListeners();
  }

  void clearDrawing() {
    drawing.clear();
    notifyListeners();
  }

  void changeGeometryType(ActivityGeometryType type) {
    drawing.changeType(type);
    notifyListeners();
  }

  Future<bool> save({
    required String activity,
    required DateTime performedAt,
    required String responsible,
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
    List<ActivityInput> inputs = const [],
  }) async {
    if (saving || geometryError != null) return false;
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.save(
        geometry: geometry,
        activity: activity,
        performedAt: performedAt,
        responsible: responsible,
        mixture: mixture,
        machine: machine,
        inputs: inputs,
      );
      drawing.clear();
      await loadEntries();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> loadEntries() async {
    entries = await repository.list();
    notifyListeners();
  }

  Future<bool> deleteLocal(String localId) async {
    if (syncing || deleting) return false;
    deleting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final deleted = await repository.deleteLocal(localId);
      await loadEntries();
      return deleted;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      deleting = false;
      notifyListeners();
    }
  }

  Future<bool> syncOne(String localId) =>
      _sync(() => repository.syncOne(localId));

  Future<bool> syncAll() => _sync(repository.syncAll);

  Future<bool> _sync(Future<bool> Function() action) async {
    if (syncing) return false;
    syncing = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      syncing = false;
      await loadEntries();
    }
  }

  void resumeLocation() {
    if (_disposed || _isLocationActive) return;
    _isLocationActive = true;
    unawaited(_locationSubscription?.cancel());
    _positionTracker.reset();
    _locationSubscription = locationService.watchLocation().listen(
      (result) {
        if (_disposed || !_isLocationActive) return;
        if (result.location case final location?) {
          final accepted = _positionTracker.add(location);
          if (accepted == null) return;
          _locationResult = LocationResult.available(accepted);
        } else {
          _positionTracker.reset();
          _locationResult = result;
        }
        notifyListeners();
      },
      onError: (Object _) {
        if (_disposed || !_isLocationActive) return;
        _positionTracker.reset();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
      onDone: () {
        if (_disposed || !_isLocationActive) return;
        _isLocationActive = false;
        _locationSubscription = null;
        _positionTracker.reset();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
    );
  }

  void pauseLocation() {
    _isLocationActive = false;
    unawaited(_locationSubscription?.cancel());
    _locationSubscription = null;
    _positionTracker.reset();
  }

  @override
  void dispose() {
    _disposed = true;
    pauseLocation();
    super.dispose();
  }
}
