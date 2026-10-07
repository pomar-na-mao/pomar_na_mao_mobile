import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/farm_point.dart';
import '../domain/farm_repository.dart';
import '../domain/plant.dart';
import '../domain/plants_repository.dart';
import '../domain/region_point.dart';
import '../domain/user_location.dart';
import '../domain/user_position_tracker.dart';
import '../domain/zone.dart';
import '../domain/zones_repository.dart';

enum PlantsLoadStatus { initial, loading, success, empty, error }

class FarmMapViewModel extends ChangeNotifier {
  FarmMapViewModel(
    this._plantsRepository,
    this._zonesRepository,
    this._locationService,
    this._farmRepository, {
    Stream<void>? plantChanges,
  }) {
    _plantChangesSubscription = plantChanges?.listen((_) {
      if (_plantsStatus == PlantsLoadStatus.initial ||
          _plantsStatus == PlantsLoadStatus.loading) {
        return;
      }
      unawaited(_reloadPlantsFromCache());
    });
  }

  final PlantsRepository _plantsRepository;
  final ZonesRepository _zonesRepository;
  final LocationService _locationService;
  final FarmRepository _farmRepository;
  StreamSubscription<LocationResult>? _locationSubscription;
  final UserPositionTracker _positionTracker = UserPositionTracker();
  StreamSubscription<void>? _plantChangesSubscription;
  bool _disposed = false;

  PlantsLoadStatus _plantsStatus = PlantsLoadStatus.initial;
  PlantsLoadStatus get plantsStatus => _plantsStatus;

  List<Plant> _allPlants = const [];
  List<Plant> get allPlants => _allPlants;
  List<Plant>? _indexedPlants;
  Map<String, Plant> _plantsById = {};
  Plant? plantById(String id) {
    if (!identical(_indexedPlants, _allPlants)) {
      _indexedPlants = _allPlants;
      _plantsById = {for (final plant in _allPlants) plant.id: plant};
    }
    return _plantsById[id];
  }

  Object? _filterKey;
  List<Plant> _filteredPlants = const [];
  List<Plant> get plants {
    final zoneId = _selectedZoneId;
    if (zoneId == null) return _allPlants;
    final key = (_allPlants, zoneId);
    if (_filterKey == key) return _filteredPlants;
    _filterKey = key;
    return _filteredPlants = _allPlants
        .where((plant) => plant.zoneId == zoneId)
        .toList(growable: false);
  }

  List<Zone> _zones = const [];
  List<Zone> get zones => _zones;

  List<FarmPoint> _farmBoundaryPoints = const [];
  List<FarmPoint> get farmBoundaryPoints => _farmBoundaryPoints;

  final Map<String, List<RegionPoint>> _zoneRegionsCache = {};
  List<RegionPoint> _selectedZonePoints = const [];
  List<RegionPoint> get selectedZonePoints => _selectedZonePoints;

  String? _selectedZoneId;
  String? get selectedZoneId => _selectedZoneId;

  LocationResult? _locationResult;
  LocationResult? get locationResult => _locationResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserLocation? get userLocation => _locationResult?.location;
  bool get canShowUserLocation =>
      _locationResult?.availability == LocationAvailability.available;

  Future<void> initialize() async {
    if (_plantsStatus != PlantsLoadStatus.initial) return;
    await loadFarmData();
  }

  Future<void> loadFarmData() async {
    _plantsStatus = PlantsLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final plantsFuture = _plantsRepository.fetchPlants();
      final zonesFuture = _zonesRepository.fetchZones();
      final farmBoundaryFuture = _loadFarmBoundarySilently();
      _allPlants = await plantsFuture;
      _zones = await zonesFuture;
      _farmBoundaryPoints = await farmBoundaryFuture;
      _plantsStatus = plants.isEmpty
          ? PlantsLoadStatus.empty
          : PlantsLoadStatus.success;
    } on Exception {
      _plantsStatus = PlantsLoadStatus.error;
      _errorMessage = 'Não foi possível carregar as plantas.';
    }
    notifyListeners();
  }

  Future<void> loadPlants() => loadFarmData();

  Future<void> _reloadPlantsFromCache() async {
    try {
      _allPlants = await _plantsRepository.fetchPlants();
      _plantsStatus = plants.isEmpty
          ? PlantsLoadStatus.empty
          : PlantsLoadStatus.success;
      _errorMessage = null;
      notifyListeners();
    } on Exception {
      // The previously displayed complete revision remains available.
    }
  }

  Future<List<FarmPoint>> _loadFarmBoundarySilently() async {
    try {
      return await _farmRepository.fetchFarmBoundary();
    } catch (_) {
      return const [];
    }
  }

  void selectZone(String? zoneId) {
    if (_selectedZoneId == zoneId) return;

    _selectedZoneId = zoneId;
    _selectedZonePoints =
        (zoneId != null && _zoneRegionsCache.containsKey(zoneId))
        ? _zoneRegionsCache[zoneId]!
        : const [];

    if (_plantsStatus != PlantsLoadStatus.loading &&
        _plantsStatus != PlantsLoadStatus.error) {
      _plantsStatus = plants.isEmpty
          ? PlantsLoadStatus.empty
          : PlantsLoadStatus.success;
    }
    notifyListeners();

    if (zoneId != null && !_zoneRegionsCache.containsKey(zoneId)) {
      unawaited(_loadZoneRegions(zoneId));
    }
  }

  Future<void> _loadZoneRegions(String zoneId) async {
    try {
      final points = await _zonesRepository.fetchRegionsForZone(zoneId);
      _zoneRegionsCache[zoneId] = points;
      if (_selectedZoneId == zoneId) {
        _selectedZonePoints = points;
        notifyListeners();
      }
    } catch (_) {
      // Falha silenciosa no polígono para manter o mapa operacional
    }
  }

  Future<void> loadUserLocation() async {
    if (_disposed || _locationSubscription != null) return;
    _positionTracker.reset();
    final hadResult = _locationResult != null;
    _locationResult = null;
    if (hadResult) scheduleMicrotask(notifyListeners);
    _locationSubscription = _locationService.watchLocation().listen(
      (result) {
        if (_disposed || _locationSubscription == null) return;
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
        if (_disposed) return;
        _positionTracker.reset();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
    );
  }

  void pauseLocation() {
    final subscription = _locationSubscription;
    _locationSubscription = null;
    unawaited(subscription?.cancel());
    _positionTracker.reset();
    final hadResult = _locationResult != null;
    _locationResult = null;
    if (hadResult) scheduleMicrotask(notifyListeners);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String? get locationMessage => switch (_locationResult?.availability) {
    LocationAvailability.permissionDenied =>
      'Permita o acesso à localização para ver sua posição.',
    LocationAvailability.serviceDisabled =>
      'Ative o serviço de localização para ver sua posição.',
    LocationAvailability.error => 'Não foi possível obter sua localização.',
    LocationAvailability.available || null => null,
  };

  @override
  void dispose() {
    _disposed = true;
    pauseLocation();
    unawaited(_plantChangesSubscription?.cancel());
    super.dispose();
  }
}
